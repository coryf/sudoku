require 'board_possibilities'
require 'board_enumerators'

class Board
  include BoardEnumerators

  attr_reader :block_size, :row_size, :cursor, :last_message

  CHAR_TO_BITMASK   = Hash[32.times.map { |x| [x.to_s, 1 << (x - 1) ] }]
  BITMASK_TO_CHAR   = CHAR_TO_BITMASK.invert
  BITMASK_TO_NUM    = Hash[BITMASK_TO_CHAR.map { |k, v| [k, v.to_i] }]
  BITCOUNT          = Hash.new { |h, k| h[k] = bitcount(k) }

  def initialize(data)
    @cursor = [0, 0]
    @row_size = Math.sqrt(data.size).to_i
    @block_size = Math.sqrt(@row_size).to_i
    @board = data.scan(/\d/).map { |x| CHAR_TO_BITMASK[x] }.each_slice(@row_size).to_a
    @possibilities = BoardPossibilities.new(self)
  end

  def [](row, col)
    @board[row][col]
  end

  def filled?
    each_cell.all? { |cell| cell != 0 }
  end

  def correct?
    rows_unique? && cols_unique? && blocks_unique?
  end

  def rows_unique?
    each_row.all? do |row|
      seen = 0
      each_in_row(row).all? do |cell|
        unique = (seen & cell) == 0
        seen |= cell
        unique
      end
    end
  end

  def cols_unique?
    each_col.all? do |col|
      seen = 0
      each_in_col(col).all? do |cell|
        unique = (seen & cell) == 0
        seen |= cell
        unique
      end
    end
  end

  def blocks_unique?
    each_block.all? do |block|
      seen = 0
      each_in_block(*block).all? do |cell, _, _|
        unique = (seen & cell) == 0
        seen |= cell
        unique
      end
    end
  end

  def solved?
    filled? && correct?
  end

  def reduced_cell(row, col, taken, message)
    @cursor = [row, col]
    taken = mask_to_array(taken).join(',')
    @last_message = "[%d, %d] #{message} %s" % [row, col, taken]
  end

  def found_cell(row, col, cell, message)
    @board[row][col] = cell
    @cursor = [row, col]
    @last_message = "[%d, %d] #{message} %d" % [row, col, BITMASK_TO_CHAR[cell]]
  end

  def self.bitcount(x)
    # works up to 32bits
    m1 = 0x55555555
    m2 = 0x33333333
    m4 = 0x0f0f0f0f
    x -= (x >> 1) & m1
    x = (x & m2) + ((x >> 2) & m2)
    x = (x + (x >> 4)) & m4
    x += x >> 8
    (x + (x >> 16)) & 0x3f
  end

  SOLVERS = [
    [:find_last_possible_cell,  'Last available'],
    [:find_last_position_block, 'Block elimination'],
    [:find_last_position_row,   'Row elimination'],
    [:find_last_position_col,   'Col elimination'],
  ]

  REDUCER = [
    [:block_vector_reduction, 'Block vector reduction'],
    [:matched_set_reduction, 'Matched set reduction'],
  ]

  def iterate_solution
    if found = each_solution(with_reducers: true).first
      if found.first == :reduced
        _, row, col, taken, message = found
        reduced_cell(row, col, taken, message)
      else
        row, col, cell, message = found
        found_cell(row, col, cell, message)
        @possibilities.take!(row, col, cell)
      end
    else
      @last_message = "Additional cell not found."
    end

    !!found
  end

  def each_solution(options = {})
    return to_enum(:each_solution, options) unless block_given?

    loop do
      found = false
      SOLVERS.each do |solver, message|
        each_position do |row, col|
          if cell = send(solver, row, col)
            found = true
            yield row, col, cell, message
          end
        end
      end

      unless found || solved?
        reduced_cell = nil
        message = ''
        REDUCER.each { |r, m| message = m; break if reduced_cell = send(r) }
        if reduced_cell
          if options[:with_reducers]
            row, col, taken = reduced_cell
            yield :reduced, row, col, taken, message
          end
          redo
        end
      end

      break unless found
    end
  end

  def block_vector_reduction
    indexes = (0...@row_size).to_a

    each_block do |block|
      @row_availables = Hash.new(0)
      @col_availables = Hash.new(0)
      each_block_position(*block) do |row, col|
        @row_availables[row] |= @possibilities[row, col]
        @col_availables[col] |= @possibilities[row, col]
      end

      block_rows = @row_availables.keys
      block_cols = @col_availables.keys

      # block row reduction
      @row_availables.each do |row, availables|
        other_availables = @row_availables.select { |r, _| r != row }.map(&:last)
        other_availables = other_availables.reduce(:|)
        exclusives = (availables ^ other_availables) & availables
        if exclusives != 0
          other_cols = (indexes - block_cols)
          other_cols.each do |col|
            if cell_empty?(row, col)
              if @possibilities.remove(row, col, exclusives)
                return [row, col, exclusives]
              end
            end
          end
        end
      end

      # block col reduction
      @col_availables.each do |col, availables|
        other_availables = @col_availables.select { |r, _| r != col }.map(&:last)
        other_availables = other_availables.reduce(:|)
        exclusives = (availables ^ other_availables) & availables
        if exclusives != 0
          other_rows = indexes - block_rows
          other_rows.each do |row|
            if cell_empty?(row, col)
              if @possibilities.remove(row, col, exclusives)
                return [row, col, exclusives]
              end
            end
          end
        end
      end
    end

    nil
  end

  def matched_set_reduction
    matches = Hash.new { |h, k| h[k] = [] }

    indexes = (0...@row_size).to_a

    each_position do |row, col|
      possible = @possibilities[row, col]
      matches[possible] << [row, col] if possible != 0
    end

    matches = matches.map { |a, positions| [BITCOUNT[a], a, positions] }.sort_by(&:first)
    matches.each do |count, possible, positions|
      # rows
      @row_size.times do |row|
        row_positions = positions.select { |r, _| row == r }
        if row_positions.size == count
          cols = row_positions.map(&:last)
          other_positions = indexes - cols
          other_positions.each do |col|
            if @possibilities.remove(row, col, possible)
              return [row, col, possible]
            end
          end
        end
      end

      # cols
      @row_size.times do |col|
        col_positions = positions.select { |_, c| col == c }

        if col_positions.size == count
          rows = col_positions.map(&:first)
          other_positions = indexes - rows
          other_positions.each do |row|
            if @possibilities.remove(row, col, possible)
              return [row, col, possible]
            end
          end
        end
      end

      # blocks
      each_block do |block|
        block_positions = positions.select { |r, c| block == block_from_position(r, c) }
        if block_positions.size == count
          other_positions = each_block_position(*block).to_a - block_positions
          other_positions.each do |row, col|
            if @possibilities.remove(row, col, possible)
              return [row, col, possible]
            end
          end
        end
      end
    end

    nil
  end

  def solve
    each_solution do |row, col, cell, _|
      @board[row][col] = cell
      @possibilities.take!(row, col, cell)
    end
  end

  def find_last_possible_cell(row, col)
    @possibilities.unique(row, col)
  end

  def find_last_position_block(row, col)
    mask = @possibilities[row, col]
    each_block_position(row, col) do |block_row, block_col|
      unless [row, col] == [block_row, block_col]
        mask &= ~@possibilities[block_row, block_col]
      end
    end
    cell = mask & @possibilities.mask

    cell if cell != 0
  end

  def find_last_position_row(row, col)
    mask = @possibilities[row, col]
    @row_size.times do |block_col|
      unless col == block_col
        mask &= ~@possibilities[row, block_col]
      end
    end
    cell = mask & @possibilities.mask

    cell if cell != 0
  end

  def find_last_position_col(row, col)
    mask = @possibilities[row, col]
    @row_size.times do |block_row|
      unless row == block_row
        mask &= ~@possibilities[block_row, col]
      end
    end
    cell = mask & @possibilities.mask

    cell if cell != 0
  end

  def available_mask(row, col)
    @possibilities[row, col]
  end

  def cell_mask(row, col)
    @board[row][col]
  end

  def cell_empty?(row, col)
    @board[row][col] == 0
  end

  def block_from_position(row, col)
    row_start = (row / @block_size) * @block_size
    col_start = (col / @block_size) * @block_size
    [row_start, col_start]
  end

  def move(*offsets)
    @cursor[0] = range_coerce(@cursor[0] + offsets[0])
    @cursor[1] = range_coerce(@cursor[1] + offsets[1])
  end

  def cursor_position?(row, col)
    @cursor == [row, col]
  end

  def available(row, col)
    mask_to_array(@possibilities[row, col])
  end

  def mask_to_array(mask)
    (0...@row_size).select { |x| mask[x] != 0 }.map(&:succ)
  end

  private

  def range_coerce(val)
    [[0, val].max, @row_size - 1].min
  end
end

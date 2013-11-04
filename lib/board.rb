require 'board_possibilities'

class Board
  attr_reader :block_size, :row_size, :cursor, :last_message

  CHAR_TO_BITMASK = Hash[32.times.map { |x| [x.to_s, 1 << (x - 1) ] }]
  BITMASK_TO_CHAR = CHAR_TO_BITMASK.invert
  BITMASK_TO_NUM  = Hash[BITMASK_TO_CHAR.map { |k, v| [k, v.to_i] }]

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

  def solved?
    each_position.all? { |row, col| @board[row][col] != 0 }
  end

  def found_cell(row, col, cell, message)
    @board[row][col] = cell
    @cursor = [row, col]
    @last_message = "[%d, %d] #{message} %d" % [row, col, BITMASK_TO_CHAR[cell]]
    true
  end

  SOLVERS = [
    [:find_last_possible_cell,  'Last available'],
    [:find_last_position_block, 'Block elimination'],
    [:find_last_position_row,   'Row elimination'],
    [:find_last_position_col,   'Col elimination'],
  ]

  REDUCER = [
    :block_vector_reduction,
  ]

  def iterate_solution
    if found = each_solution.first
      row, col, cell, message = found
      found_cell(row, col, cell, message)
      @possibilities.take!(row, col, cell)
    else
      @last_message = "Additional cell not found."
    end

    !!found
  end

  def each_solution
    return to_enum(:each_solution) unless block_given?

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
        reduced = false
        REDUCER.each { |r| break if reduced = send(r) }
        redo if reduced
      end

      break unless found
    end
  end

  def block_vector_reduction
    reduced = false
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
          ((0...@row_size).to_a - block_cols).each do |col|
            if cell_empty?(row, col)
              #logit([:row, row, col, "%09b" % availables, "%09b" % other_availables, "%09b" % exclusives, block_cols])
              reduced ||= @possibilities.remove(row, col, exclusives)
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
          ((0...@row_size).to_a - block_rows).each do |row|
            if cell_empty?(row, col)
              #logit([:col, row, col, "%09b" % availables, "%09b" % other_availables, "%09b" % exclusives, block_rows])
              reduced ||= @possibilities.remove(row, col, exclusives)
            end
          end
        end
      end
    end
    reduced
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

  def each_in_row(row)
    @board[row].each
  end

  def each_in_col(col)
    @board.map { |line| line[col] }
  end

  def each_block
    return to_enum(:each_block) unless block_given?

    (0...@row_size).step(@block_size) do |row|
      (0...@row_size).step(@block_size) do |col|
        yield [row, col]
      end
    end
  end

  def block_from_position(row, col)
    row_start = (row / @block_size) * @block_size
    col_start = (col / @block_size) * @block_size
    [row_start, col_start]
  end

  def each_block_position(row, col)
    return to_enum(:each_block_position, row, col).map(&:first) unless block_given?

    row_start, col_start = block_from_position(row, col)

    row_end = row_start + @block_size
    col_end = col_start + @block_size

    (row_start...row_end).each do |block_row|
      (col_start...col_end).each do |block_col|
        yield [block_row, block_col]
      end
    end
  end

  def each_position
    return to_enum(:each_position) unless block_given?

    @row_size.times.each do |row|
      @row_size.times.each do |col|
        yield [row, col]
      end
    end
  end

  def each_cell
    return to_enum(:each_cell) unless block_given?

    @board.each_with_index do |line, row|
      line.each_with_index do |cell, col|
        yield [cell, row, col]
      end
    end
  end

  def each_in_block(row, col)
    return to_enum(:each_in_block, row, col).map(&:first) unless block_given?

    each_block_position(row, col) do |block_row, block_col|
      yield [@board[block_row][block_col], block_row, block_col]
    end
  end

  def move(*offsets)
    @cursor[0] = range_coerce(@cursor[0] + offsets[0])
    @cursor[1] = range_coerce(@cursor[1] + offsets[1])
  end

  def cursor_position?(row, col)
    @cursor == [row, col]
  end

  def available(row, col)
    mask = @possibilities[row, col]
    (0...@row_size).select { |x| mask[x] != 0 }.map(&:succ)
  end

  def each_num_row
    return to_enum(:each_num_row) unless block_given?

    @board.each do |line|
      yield line.map { |x| BITMASK_TO_NUM[x] }.each
    end
  end

  private

  def range_coerce(val)
    [[0, val].max, @row_size - 1].min
  end
end

class Board
  attr_reader :block_size, :row_size, :cursor, :last_message

  CHAR_TO_BITMASK = Hash[32.times.map { |x| [x.to_s, 1 << (x - 1) ] }]
  BITMASK_TO_CHAR = CHAR_TO_BITMASK.invert
  BITMASK_TO_NUM  = Hash[BITMASK_TO_CHAR.map { |k, v| [k, v.to_i] }]

  def initialize(data)
    @cursor = [0, 0]
    @row_size = Math.sqrt(data.size).to_i
    @block_size = Math.sqrt(@row_size).to_i
    @available_mask = (1 << (@row_size)) - 1
    @board = data.scan(/\d/).map { |x| CHAR_TO_BITMASK[x] }.each_slice(@row_size).to_a
    reset_available
  end

  def reset_available
    @available = @row_size.times.map do |row|
      @row_size.times.map do |col|
        if @board[row][col] == 0
          cell_available(row, col)
        else
          0
        end
      end
    end
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

  def iterate_solution
    cell_found = false

    each_position do |row, col|
      if cell = find_only_available(row, col)
        cell_found = found_cell(row, col, cell, 'Last available')
        break
      end

      if cell = find_only_possible_block(row, col)
        cell_found = found_cell(row, col, cell, 'Block elimination')
        break
      end

      if cell = find_only_possible_row(row, col)
        cell_found = found_cell(row, col, cell, 'Row elimination')
        break
      end

      if cell = find_only_possible_col(row, col)
        cell_found = found_cell(row, col, cell, 'Col elimination')
        break
      end
    end

    if cell_found
      reset_available
    else
      @last_message = "Additional cell not found."
    end

    cell_found
  end

  def find_only_available(row, col)
    cell = @available[row][col]
    if cell != 0 && BITMASK_TO_NUM[cell]
      cell
    end
  end

  def find_only_possible_block(row, col)
    mask = @available[row][col]
    each_block_position(row, col) do |block_row, block_col|
      unless [row, col] == [block_row, block_col]
        available = @available[block_row][block_col]
        mask &= ~available
      end
    end
    cell = mask & @available_mask

    cell if cell != 0
  end

  def find_only_possible_row(row, col)
    mask = @available[row][col]
    @row_size.times do |block_col|
      unless col == block_col
        available = @available[row][block_col]
        mask &= ~available
      end
    end
    cell = mask & @available_mask

    cell if cell != 0
  end

  def find_only_possible_col(row, col)
    mask = @available[row][col]
    @row_size.times do |block_row|
      unless row == block_row
        available = @available[block_row][col]
        mask &= ~available
      end
    end
    cell = mask & @available_mask

    cell if cell != 0
  end

  def available_mask(row, col)
    @available[row][col]
  end

  def cell_mask(row, col)
    @board[row][col]
  end

  def cell_available(row, col)
    ~( each_in_row(row).reduce(:|) |
       each_in_col(col).reduce(:|) |
       each_in_block(row, col).reduce(:|)
     ) & @available_mask
  end

  def each_in_row(row)
    @board[row].each
  end

  def each_in_col(col)
    @board.map { |line| line[col] }
  end

  def each_block_position(row, col)
    return to_enum(:each_block_position, row, col).map(&:first) unless block_given?

    row_start = (row / @block_size) * @block_size
    col_start = (col / @block_size) * @block_size

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
    mask = @available[row][col]
    (0...@row_size).select { |x| mask[x] != 0 }.map(&:succ)
  end

  def each_num_row
    @board.map { |line| line.map { |x| BITMASK_TO_NUM[x] } }
  end

  private

  def range_coerce(val)
    [[0, val].max, @row_size - 1].min
  end
end

class Board
  attr_reader :block_size, :row_size, :cursor

  CHAR_TO_BITMASK = Hash[32.times.map { |x| [x.to_s, 1 << (x - 1) ] }]
  BITMASK_TO_CHAR = CHAR_TO_BITMASK.invert
  BITMASK_TO_NUM  = Hash[BITMASK_TO_CHAR.map { |k, v| [k, v.to_i] }]

  def initialize(data)
    @cursor = [0, 0]
    @row_size = Math.sqrt(data.size).to_i
    @block_size = Math.sqrt(@row_size).to_i
    @board = data.scan(/\d/).map { |x| CHAR_TO_BITMASK[x] }.each_slice(@row_size).to_a
    initialize_available
  end

  def initialize_available
    @available = @row_size.times.map do |row|
      @row_size.times.map do |col|
        cell_available(row, col)
      end
    end
  end

  def cell_available(row, col)
    ~( each_in_row(row).reduce(:|) |
       each_in_col(col).reduce(:|) |
       each_in_block(row, col).reduce(:|)
     )
  end

  def each_in_row(row)
    @board[row].each
  end

  def each_in_col(col)
    @board.map { |line| line[col] }
  end

  def each_in_block(row, col)
    return to_enum(:each_in_block, row, col) unless block_given?

    row_start = (row / @block_size) * @block_size
    col_start = (col / @block_size) * @block_size

    row_end = row_start + @block_size
    col_end = col_start + @block_size

    (row_start...row_end).each do |block_row|
      (col_start...col_end).each do |block_col|
        yield @board[block_row][block_col]
      end
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

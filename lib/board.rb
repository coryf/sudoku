class Board
  attr_reader :block_size

  CHAR_TO_BITMASK = Hash[16.times.map { |x| [x.to_s, 1 << (x - 1) ] }]
  BITMASK_TO_CHAR = CHAR_TO_BITMASK.invert
  BITMASK_TO_NUM  = Hash[BITMASK_TO_CHAR.map { |k, v| [k, v.to_i] }]

  def initialize(data)
    @cursor = [0, 0]
    @board = data.scan(/\d/).map { |x| CHAR_TO_BITMASK[x] }.each_slice(9)
    @block_size = 3
    @grid_size = @block_size ** 2
  end

  def move(*offsets)
    @cursor[0] = range_coerce(@cursor[0] + offsets[0])
    @cursor[1] = range_coerce(@cursor[1] + offsets[1])
  end

  def cursor_position?(row, col)
    @cursor == [row, col]
  end

  def each_num_row
    @board.map { |line| line.map { |x| BITMASK_TO_NUM[x] } }
  end

  private

  def range_coerce(val)
    [[0, val].max, @grid_size - 1].min
  end
end

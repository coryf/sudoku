class BoardPossibilities
  attr_accessor :board
  attr_reader :mask

  def initialize(board)
    @board = board
    @mask = (1 << (board.row_size)) - 1
    recalculate
  end

  def recalculate
    @row_taken = board.row_size.times.map do |row|
      board.each_in_row(row).reduce(:|)
    end

    @col_taken = board.row_size.times.map do |col|
      board.each_in_col(col).reduce(:|)
    end

    @block_taken = Hash[board.each_block.map do |block|
      [block, board.each_in_block(*block).reduce(:|)]
    end]

    update_possibilities
  end

  def cell_taken(row, col, cell)
    block = board.block_from_position(row, col)
    @row_taken[row]     |= cell
    @col_taken[col]     |= cell
    @block_taken[block] |= cell

    update_possibilities
  end

  def update_possibilities
    @possibilities = board.row_size.times.map do |row|
      board.row_size.times.map do |col|
        if board.cell_mask(row, col) == 0
          cell_possibilities(row, col)
        else
          0
        end
      end
    end
  end

  def cell_possibilities(row, col, block = nil)
    block ||= board.block_from_position(row, col)
    ~( @row_taken[row] | @col_taken[col] | @block_taken[block] ) & @mask
  end

  def [](row, col)
    @possibilities[row][col]
  end

  def unique(row, col)
    cell = @possibilities[row][col]
    if cell != 0 && Board::BITMASK_TO_NUM[cell]
      cell
    end
  end
end

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

    @possibilities = board.row_size.times.map do |row|
      board.row_size.times.map do |col|
        if board[row, col] == 0
          cell_possibilities(row, col)
        else
          0
        end
      end
    end
  end

  def cell_possibilities(row, col)
    block = board.block_from_position(row, col)
    ~( @row_taken[row] |
       @col_taken[col] |
       @block_taken[block]
     ) & @mask
  end

  def [](row, col)
    @possibilities[row][col]
  end
end

class BoardPossibilities
  attr_accessor :board
  attr_reader :mask

  def initialize(board)
    @board = board
    @mask = (1 << (board.row_size)) - 1
    recalculate
  end

  def recalculate
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
    ~( board.each_in_row(row).reduce(:|) |
      board.each_in_col(col).reduce(:|) |
      board.each_in_block(row, col).reduce(:|)
     ) & @mask
  end

  def [](row, col)
    @possibilities[row][col]
  end
end

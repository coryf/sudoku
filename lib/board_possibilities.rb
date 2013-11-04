class BoardPossibilities
  attr_accessor :board
  attr_reader :mask

  def initialize(board)
    @board = board
    @mask = (1 << (board.row_size)) - 1
    everythings_possible!
    recalculate
  end

  def everythings_possible!
    @possibilities = board.row_size.times.map do |row|
      board.row_size.times.map { |col| @mask }
    end
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

    update
  end

  def take!(row, col, cell)
    block = board.block_from_position(row, col)
    @row_taken[row]     |= cell
    @col_taken[col]     |= cell
    @block_taken[block] |= cell

    update
  end

  def remove(row, col, remove_mask)
    possible = @possibilities[row][col]
    @possibilities[row][col] = (possible & ~remove_mask) & @mask

    @possibilities[row][col] != possible
  end

  def update
    @possibilities.each_with_index do |line, row|
      line.each_with_index do |possible, col|
        @possibilities[row][col] = if board.cell_empty?(row, col)
          possible & ~taken(row, col)
        else
          0
        end
      end
    end
  end

  def taken(row, col, block = nil)
    block ||= board.block_from_position(row, col)
    @row_taken[row] | @col_taken[col] | @block_taken[block]
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

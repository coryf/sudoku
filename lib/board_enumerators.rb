module BoardEnumerators
  def each_cell
    return to_enum(:each_cell) unless block_given?

    @board.each do |line|
      line.each do |cell|
        yield cell
      end
    end
  end

  def each_row
    @row_size.times
  end

  def each_col
    @row_size.times
  end

  def each_block
    return to_enum(:each_block) unless block_given?

    (0...@row_size).step(@block_size) do |row|
      (0...@row_size).step(@block_size) do |col|
        yield [row, col]
      end
    end
  end

  def each_in_row(row)
    @board[row].each
  end

  def each_in_col(col)
    @board.map { |line| line[col] }
  end

  def each_in_block(row, col)
    return to_enum(:each_in_block, row, col) unless block_given?

    each_block_position(row, col) do |block_row, block_col|
      yield [@board[block_row][block_col], block_row, block_col]
    end
  end

  def each_block_position(row, col)
    return to_enum(:each_block_position, row, col).map unless block_given?

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

  def each_num_row
    return to_enum(:each_num_row) unless block_given?

    @board.each do |line|
      yield line.map { |x| Board::BITMASK_TO_NUM[x] }.each
    end
  end
end

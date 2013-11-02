class BoardView
  attr_reader :board, :block_size
  attr_reader :top_line, :bottom_line, :middle_line, :block_middle_line

  CELL_NORMAL   = " %s "
  CELL_SELECTED = "[%s]"
  CELL_CHAR_LEN = 3

  def initialize(board, grid_chars)
    @board = board
    @block_size = board.block_size

    @chars = grid_chars

    @top_line          = build_line(*chars(:tl,    :tr,    :tp,      :tp_vl,   :h  ))
    @bottom_line       = build_line(*chars(:bl,    :br,    :bp,      :bp_vl,   :h  ))
    @middle_line       = build_line(*chars(:lp,    :rp,    :plus,    :plus_vl, :h  ))
    @block_middle_line = build_line(*chars(:lp_hl, :rp_hl, :plus_hl, :plus_l,  :h_l))
  end

  def render_line(line, row)
    line = line.map.with_index do |num, col| 
      cell = board.cursor_position?(row, col) ? CELL_SELECTED : CELL_NORMAL
      num = " " if num == 0
      cell % num
    end
    line = line.each_slice(block_size).map { |l| l.join(char(:v_l)) }.join(char(:v))
    char(:v) + line + char(:v)
  end

  def render_middle_lines(lines)
    blocks = lines.each_slice(block_size).map do |block_lines| 
      block_lines.join("\n#{block_middle_line}\n")
    end
    blocks.join("\n#{middle_line}\n")
  end

  def render
    board_lines = board.each_num_row.map.with_index { |line, row| render_line(line, row) }
    board_chars = render_middle_lines(board_lines)
    [top_line, board_chars, bottom_line].join("\n")
  end

  private

  def char(key)
    @chars[key]
  end

  def chars(*keys)
    @chars.values_at(*keys)
  end

  def build_line(left, right, delim, delim_l, horz)
    line = block_size.times.map do 
      block_size.times.map { horz * CELL_CHAR_LEN }.join(delim_l)
    end
    left + line.join(delim) + right
  end
end


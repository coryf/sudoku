require 'forwardable'

class BoardDataFile
  extend Enumerable
  extend Forwardable

  def_delegators :@data, :size, :each, :first, :[]

  def initialize(filename)
    @data = File.readlines(filename).map(&:chomp).to_a
  end

  def random
    self[rand(size)]
  end

  def self.export_sparse_data(board)
    [board.row_size].pack('C') +
      if board.row_size < 16
        board.row_size.times.map do |row|
          board.row_size.times.map do |col|
            cell = board[row, col]
            next if cell == 0
            [col << 4 | Board::BITMASK_TO_NUM[cell]].pack('C')
          end.compact.join('') + "\0"
        end.join('')
      else
        board.row_size.times.map do |row|
          board.row_size.times.map do |col|
            cell = board[row, col]
            next if cell == 0
            [col, Board::BITMASK_TO_NUM[cell]].pack('CC')
          end.compact.join('') + "\0"
        end.join('')
      end
  end

  def self.import_sparse_data(data)
    row_size, data = data.unpack('Ca*')
    if row_size < 16
      row_size.times.map do |row|
        row_data, data = data.unpack('Z*a*')
        line = [0] * row_size
        col_data = row_data.unpack('C*')
        col_data.each do |packed_col|
          line[packed_col >> 4] = packed_col & 0xf
        end
        line
      end
    else
      row_size.times.map do |row|
        row_data, data = data.unpack('Z*a*')
        line = [0] * row_size
        col_data = row_data.unpack('S*')
        col_data.each do |packed_col|
          line[packed_col >> 8] = packed_col & 0xff
        end
        line
      end
    end
  end

end


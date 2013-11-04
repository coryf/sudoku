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

  def find(number)
    if (1..size).cover? number
      self[number - 1]
    end
  end

  def self.export_sparse_data(board)
    offset, pack_row = board.row_size > 16 ? [8, 'CS*'] : [4, 'CC*']
    rows = board.each_num_row.with_index.map do |line, row|
      cols = line.with_index.select { |cell, _| cell != 0 }
      row = cols.map { |cell, col| (col << offset) | (cell - 1) }
      [row.size, *row].pack(pack_row)
    end
    [board.row_size].pack('C') + rows.join('')
  end

  def self.import_sparse_data(data)
    row_size, data = data.unpack('Ca*')

    offset, pack_code = row_size > 16 ? [8, 'S'] : [4, 'C']
    col_mask = (1 << offset) - 1

    row_size.times.map do |row|
      col_count, data = data.unpack("Ca*")
      line = [0] * row_size
      if col_count > 0
        *col_data, data = data.unpack("#{pack_code}#{col_count}a*")
        col_data.each do |packed_col|
          line[packed_col >> offset] = (packed_col & col_mask) + 1
        end
      end
      line
    end
  end

end

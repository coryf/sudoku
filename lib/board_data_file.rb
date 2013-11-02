require 'forwardable'

class BoardDataFile
  extend Enumerable
  extend Forwardable

  def_delegators :@data, :size, :first

  def initialize(filename)
    @data = File.readlines(filename)
  end

  def each
    @data.lazy.map(&:chomp).each
  end

  def [](index)
    @data[index].chomp
  end

  def random
    @data[rand(@data.size)].chomp
  end
end


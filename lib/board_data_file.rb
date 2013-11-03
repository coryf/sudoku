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
end


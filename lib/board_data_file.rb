require 'forwardable'

class BoardDataFile
  extend Enumerable
  extend Forwardable

  def_delegators :@data, :size, :each, :first, :[]

  def initialize(filename)
    @data = File.readlines(filename).lazy.map(&:chomp)
  end

  def random
    self[rand(size)]
  end
end


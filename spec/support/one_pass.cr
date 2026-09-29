module SpecSupport
  # :nodoc:
  # A collection that yields its items once and raises on a second pass, so a
  # spec can check that a component copies a one-pass input. It declares
  # `Enumerable(T?)` so the component must accept a wider declared type than
  # the values it receives.
  class OnePass(T)
    include Enumerable(T?)

    getter passes : Int32 = 0

    def initialize(@items : Array(T))
    end

    def each(&) : Nil
      @passes += 1
      raise "Traversed twice" if @passes > 1
      @items.each { |item| yield item }
    end
  end
end

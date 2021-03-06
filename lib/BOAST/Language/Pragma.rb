module BOAST

  # @!parse module Functors; functorize Pragma; end
  class Pragma
    include PrivateStateAccessor
    include Inspectable
    extend Functor

    attr_reader :name
    attr_reader :options

    def initialize(name, *options)
      @name = name
      @options = options
    end

    def to_s
      s = ""
      if lang == FORTRAN then
        s += "!#{@name}$"
      else
        s += "#pragma #{name}"
      end
      @options.each{ |opt|
        s += " #{opt}"
      }
      return s
    end

    def pr
      s=""
      s += to_s
      output.puts s
      return self
    end
  end

end

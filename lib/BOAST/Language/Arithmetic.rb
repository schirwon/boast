module BOAST
  module Arithmetic

    def **(x)
      return Expression::new(Exponentiation,self,x)
    end

    def ===(x)
      return Expression::new(Affectation,self,x)
    end

    def !
      return Expression::new(Not,nil,self)
    end

    def ==(x)
      return Expression::new(Equal,self,x)
    end

    def !=(x)
      return Expression::new(Different,self,x)
    end

    def >(x)
      return Expression::new(Greater,self,x)
    end
 
    def <(x)
      return Expression::new(Less,self,x)
    end
 
    def >=(x)
      return Expression::new(GreaterOrEqual,self,x)
    end
 
    def <=(x)
      return Expression::new(LessOrEqual,self,x)
    end
 
    def +(x)
      return Expression::new(Addition,self,x)
    end

    def -(x)
      return Expression::new(Substraction,self,x)
    end
 
    def *(x)
      return Expression::new(Multiplication,self,x)
    end

    def /(x)
      return Expression::new(Division,self,x)
    end
 
    def -@
      return Expression::new(Minus,nil,self)
    end

    def +@
      return Expression::new(Plus,nil,self)
    end

    def address
      return Expression::new("&",nil,self)
    end
   
    def dereference
      return Expression::new("*",nil,self)
    end

    def and(x)
      return Expression::new(And, self, x)
    end

    alias & and

    def or(x)
      return Expression::new(Or, self, x)
    end

    alias | or

    def cast(type)
      return type.copy("(#{type.type.decl} *)#{self}")
    end

    def components( range )
      if self.type.vector_length == 1
        return self
      else
        existing_set = [*('0'..'9'),*('a'..'z')].first(self.type.vector_length)
        eval "self.s#{existing_set[range].join("")}"
      end
    end

  end
end

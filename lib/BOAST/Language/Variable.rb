module BOAST

  class Dimension
    include PrivateStateAccessor
    include Inspectable
    extend Functor

    attr_reader :val1
    attr_reader :val2
    attr_reader :size

    def initialize(v1=nil,v2=nil)
      if v1 then
        if v2 then
          #@size = Expression::new(Substraction, v2, v1) + 1
          @size = v2-v1+1
        else
          @size = v1
        end
      else
        @size = nil
      end
      @val1 = v1
      @val2 = v2
    end

    def to_s
      if lang == FORTRAN and @val2 then
        return "#{@val1}:#{@val2}"
      elsif lang == FORTRAN and get_array_start != 1 then
        return "#{get_array_start}:#{@size-(1+get_array_start)}"
      else
        return @size
      end 
    end

    def start
      if @val2 then
        return @val1
      else
        return get_array_start
      end
    end

    def finish
      if @val2 then
        return @val2
      elsif @size
        if 0.equal?(get_array_start) then
          if 1.equal?(get_array_start) then
            return Expression::new(Addition, @size, get_array_start) - 1
          else
            return @size
          end
        else
          return Expression::new(Substraction, @size, 1)
        end
      else
        return nil
      end
    end

  end

  class ConstArray < Array
    include PrivateStateAccessor
    include Inspectable

    def initialize(array,type = nil)
      super(array)
      @type = type::new if type
    end

    def to_s
      return to_s_fortran if lang == FORTRAN
      return to_s_c if [C, CL, CUDA].include?( lang )
    end

    def to_s_fortran
      s = ""
      return s if first.nil?
      s += "(/ &\n"
      s += first.to_s
      s += @type.suffix if @type
      self[1..-1].each { |v|
        s += ", &\n"+v.to_s
        s += @type.suffix if @type
      }
      s += " /)"
    end

    def to_s_c
      s = ""
      return s if first.nil?
      s += "{\n"
      s += first.to_s
      s += @type.suffix if @type 
      self[1..-1].each { |v|
        s += ",\n"+v.to_s
        s += @type.suffix if @type
      }
      s += "}"
    end
  end

  class Variable
    include PrivateStateAccessor
    include Arithmetic
    include Inspectable
    extend Functor

    alias_method :orig_method_missing, :method_missing

    def method_missing(m, *a, &b)
      if @type.methods.include?(:members) and @type.members[m.to_s] then
        return struct_reference(type.members[m.to_s])
      elsif @type.methods.include?(:vector_length) and @type.vector_length > 1 and m.to_s[0] == 's' and lang == CL then
        required_set = m.to_s[1..-1].chars.to_a
        existing_set = [*('0'..'9'),*('a'..'z')].first(@type.vector_length)
        if required_set.length == required_set.uniq.length and (required_set - existing_set).empty? then
          return self.copy(name+"."+m.to_s, :vector_length => m.to_s[1..-1].length)
        else
          return orig_method_missing(m, *a, &b)
        end
      else
        return orig_method_missing(m, *a, &b)
      end
    end

    attr_reader :name
    attr_accessor :direction
    attr_accessor :constant
    attr_reader :allocate
    attr_reader :type
    attr_reader :dimension
    attr_reader :local
    attr_reader :texture
    attr_reader :sampler
    attr_reader :restrict
    attr_reader :deferred_shape
    attr_accessor :align
    attr_accessor :replace_constant
    attr_accessor :force_replace_constant

    def constant?
      !!@constant
    end

    def allocate?
      !!@allocate
    end

    def texture?
      !!@texture
    end

    def local?
      !!@local
    end

    def restrict?
      !!@restrict
    end

    def replace_constant?
      !!@replace_constant
    end

    def force_replace_constant?
      !!@force_replace_constant
    end

    def dimension?
      !!@dimension
    end

    def scalar_output?
      !!@scalar_output
    end

    def align?
      !!@align
    end

    def deferred_shape?
      !!@deferred_shape
    end

    def initialize(name,type,hash={})
      @name = name.to_s
      @direction = hash[:direction] ? hash[:direction] : hash[:dir]
      @constant = hash[:constant] ? hash[:constant]  : hash[:const]
      @dimension = hash[:dimension] ? hash[:dimension] : hash[:dim]
      @local = hash[:local] ? hash[:local] : hash[:shared]
      @texture = hash[:texture]
      @allocate = hash[:allocate]
      @restrict = hash[:restrict]
      @align = hash[:align]
      @deferred_shape = hash[:deferred_shape]
      @force_replace_constant = false
      if not hash[:replace_constant].nil? then
        @replace_constant = hash[:replace_constant]
      else
        @replace_constant = true
      end
      if @texture and lang == CL then
        @sampler = Variable::new("sampler_#{name}", CustomType,:type_name => "sampler_t" ,:replace_constant => false, :constant => "CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_NONE | CLK_FILTER_NEAREST")
      else
        @sampler = nil
      end
      @type = type::new(hash)
      @options = hash
      if (@direction == :out or @direction == :inout) and not dimension? then
        @scalar_output = true
      else
        @scalar_output = false
      end
      @dimension = [@dimension].flatten if dimension?
    end

    def copy(name=nil,options={})
      name = @name if not name
      h = @options.clone
      options.each { |k,v|
        h[k] = v
      }
      return Variable::new(name, @type.class, h)
    end

    def self.from_type(name, type, options={})
      hash = type.to_hash
      options.each { |k,v|
        hash[k] = v
      }
      hash[:direction] = nil
      hash[:dir] = nil
      return Variable::new(name, type.class, hash)
    end
  
    def to_s
      if force_replace_constant? or ( replace_constant? and constant? and replace_constants? and not dimension? ) then
        s = @constant.to_s + @type.suffix
        return s
      end
      if @scalar_output and [C, CL, CUDA].include?( lang ) and not decl_module? then
        return "(*#{name})"
      end
      return @name
    end

    def to_var
      return self
    end

    def set(x)
      return Expression::new(Set, self, x)
    end

    def dereference
      return copy("*(#{name})", :dimension => nil, :dim => nil, :direction => nil, :dir => nil) if [C, CL, CUDA].include?( lang )
      return self if lang == FORTRAN
      #return Expression::new("*",nil,self)
    end
   
    def struct_reference(x)
      return x.copy(name+"."+x.name) if [C, CL, CUDA].include?( lang )
      return x.copy(name+"%"+x.name) if lang == FORTRAN
    end
 
    def inc
      return Expression::new("++",self,nil)
    end

    def [](*args)
      return Index::new(self,args)
    end
 
    def finalize
       s = ""
       s += ";" if [C, CL, CUDA].include?( lang )
       s+="\n"
       return s
    end

    def boast_header(lang=C)
      return decl_texture_s if texture?
      s = ""
      s += "const " if constant? or @direction == :in
      s += @type.decl
      if dimension? then
        s += " *" unless use_vla?
      end
      if not dimension? and ( lang == FORTRAN or @direction == :out or @direction == :inout ) then
        s += " *"
      end
      s += " #{@name}"
      if dimension? and use_vla? then
        s += "["
        s += @dimension.reverse.collect { |d|
          dim = d.to_s
          if dim then
            dim.to_s
          else
            ""
          end
        }.join("][")
        s += "]"
      end
      return s
    end

    def decl_ffi(alloc, lang)
      return :pointer if lang == FORTRAN and not alloc
      return :pointer if dimension?
      return :pointer if @direction == :out or @direction == :inout and not alloc
      return @type.decl_ffi
    end

    def decl
      return decl_fortran if lang == FORTRAN
      return decl_c if [C, CL, CUDA].include?( lang )
    end

    def decl_c_s(device = false)
      return decl_texture_s if texture?
      s = ""
      s += "const " if constant? or @direction == :in
      s += "__global " if @direction and dimension? and not (@options[:register] or @options[:private] or local?) and lang == CL
      s += "__local " if local? and lang == CL
      s += "__shared__ " if local? and not device and lang == CUDA
      s += @type.decl
      if use_vla? and dimension? and not decl_module? then
        s += " #{@name}["
        s += @dimension.reverse.collect { |d|
          dim = d.to_s
          if dim then
            dim.to_s
          else
            ""
          end
        }.join("][")
        s += "]"
      else
        if dimension? and not constant? and not allocate? and (not local? or (local? and device)) then
          s += " *"
          if restrict? and not decl_module? then
            if lang == CL
              s += " restrict"
            else
              s += " __restrict__" unless use_vla?
            end
          end
        end
        if not dimension? and ( @direction == :out or @direction == :inout ) then
          s += " *"
        end
        s += " #{@name}"
        if dimension? and constant? then
          s += "[]"
        end
        if dimension? and ((local? and not device) or (allocate? and not constant?)) then
          s +="[("
          s += @dimension.collect{ |d| d.to_s }.reverse.join(")*(")
          s +=")]"
        end 
      end
      if dimension? and (align? or default_align > 1) and (constant? or allocate?) then
        a = ( align? ? align : 1 )
        a = ( a >= default_align ? a : default_align )
        s+= " __attribute((aligned(#{a})))"
      end
      s += " = #{@constant}" if constant?
      return s
    end

    def decl_texture_s
      raise "Unsupported language #{lang} for texture!" if not [CL, CUDA].include?( lang )
      raise "Write is unsupported for textures!" if not (constant? or @direction == :in)
      dim_number = 1
      if dimension? then
        dim_number == @dimension.size
      end
      raise "Unsupported number of dimension: #{dim_number}!" if dim_number > 3
      s = ""
      if lang == CL then
        s += "__read_only "
        if dim_number < 3 then
          s += "image2d_t " #from OCL 1.2+ image1d_t is defined
        else
          s += "image3d_t "
        end
      else
        s += "texture<#{@type.decl}, cudaTextureType#{dim_number}D, cudaReadModeElementType> "
      end
      s += @name
      return s
    end

    def decl_c
      s = ""
      s += indent
      s += decl_c_s
      s += finalize
      output.print s
      return self
    end

    def pr_align_c_s(a)
      return "__assume_aligned(#{@name}, #{a})"
    end

    def pr_align_c(a)
      s = ""
      s += indent
      s += pr_align_c_s(a)
      s += finalize
      output.print s
      return self
    end

    def pr_align_fortran_s(a)
      return "!DIR$ ASSUME_ALIGNED #{@name}: #{a}"
    end

    def pr_align_fortran(a)
      s = ""
      s += indent
      s += pr_align_fortran_s(a)
      s += finalize
      output.print s
      return self
    end

    def pr_align
      if dimension? then
        if align? or default_align > 1 then
          a = ( align? ? align : 1 )
          a = ( a >= default_align ? a : default_align )
          return pr_align_c(a) if lang == C
          return pr_align_fortran(a) if lang == FORTRAN
        end
      end
    end

    def decl_fortran
      s = ""
      s += indent
      s += @type.decl
      s += ", intent(#{@direction})" if @direction 
      s += ", parameter" if constant?
      if dimension? then
        s += ", dimension("
        s += @dimension.collect { |d|
          dim = d.to_s
          if dim then
            dim.to_s
          elsif deferred_shape?
            ":"
          else
            "*"
          end
        }.join(", ")
        s += ")"
      end
      s += " :: #{@name}"
      if constant? then
        s += " = #{@constant}"
        s += @type.suffix if not dimension? and @type
      end
      s += finalize
      output.print s
      if dimension? and (align? or default_align > 1) and (constant? or allocate?) then
        a = ( align? ? align : 1 )
        a = ( a >= default_align ? a : default_align )
        s = ""
        s += indent
        s += "!DIR$ ATTRIBUTES ALIGN: #{a}:: #{name}"
        s += finalize
        output.print s
      end
      return self
    end

  end

end
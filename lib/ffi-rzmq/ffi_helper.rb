
module FFI
  class CArray
    include Enumerable
    
    attr_reader :size
    
    def initialize struct, count = 32, clear_memory = true
      @struct_klass = struct.class
      @element_size = struct.size
      @capacity = count
      @byte_size = @element_size * @capacity
      @size = 0
      @store = FFI::MemoryPointer.new :char, @size, clear_memory
    end
    
    def address
      @store
    end
    
    def get index
      pointer = @store + (@size * @element_size * index)
      @struct_klass.new pointer
    end
    alias :[] :get
    
    def <<(obj)
      raise ArgumentError.new("This array can only hold [#{@capacity}] elements") if @size + 1 >= @capacity
      struct = get size
      obj.members.each do |key|
        struct[key] = obj[key]
      end
      
      @size += 1
    end
    
    def each &blk
      index = 0
      until index > @size do
        struct = get index
        yield struct
        index += 1
      end
    end

  end # class CArray
end # module FFI

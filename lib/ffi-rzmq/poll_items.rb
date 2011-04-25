
module ZMQ
  class PollItems
    include Enumerable

    def initialize
      @element_size = LibZMQ::PollItem.size
      @store = nil
      @items = []
    end

    def size; @items.size; end

    def empty?; @items.empty?; end

    def address
      clean
      @store
    end

    def get index
      unless @items.empty? || index.nil?
        clean

        # pointer arithmetic in ruby! whee!
        pointer = @store + (@element_size * index)

        # cast the memory to a PollItem
        LibZMQ::PollItem.new pointer
      end
    end
    alias :[] :get

    def <<(obj)
      @dirty = true
      @items << obj
    end
    alias :push :<<
    
    def delete sock
      address = sock.socket.address
      found = false
      
      each_with_index do |item, index|
        if address == item[:socket].address
          @items.delete_at index
          found = true
          @dirty = true
          clean
          break
        end
      end
      
      # these semantics are different from the usual Array#delete; returns a
      # boolean instead of the actual item or nil
      found
    end
    
    def delete_at index
      value = nil
      unless @items.empty?
        value = @items.delete_at index
        @dirty = true
        clean
      end
      
      value
    end

    def each &blk
      clean
      index = 0
      until index >= @items.size do
        struct = get index
        yield struct
        index += 1
      end
    end

    def each_with_index &blk
      clean
      index = 0
      until index >= @items.size do
        struct = get index
        yield struct, index
        index += 1
      end
    end
    
    def inspect
      clean
      str = ""
      each { |item| str << "ptr [#{item[:socket]}], events [#{item[:events]}], revents [#{item[:revents]}], " }
      str.chop.chop
    end
    
    def to_s(); inspect; end

    private

    # Allocate a contiguous chunk of memory and copy over the PollItem structs
    # to this block. Note that the old +@store+ value goes out of scope so when
    # it is garbage collected that native memory should be automatically freed.
    def clean
      if @dirty
        @store = FFI::MemoryPointer.new @element_size, @items.size, true

        # copy over
        offset = 0
        @items.each do |item|
          LibC.memcpy(@store + offset, item.pointer, @element_size)
          offset += @element_size
        end

        @dirty = false
      end
    end

  end # class PollItems
end # module ZMQ

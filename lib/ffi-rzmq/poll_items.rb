
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

    def each &blk
      clean
      index = 0
      until index >= @size do
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

    private

    # Allocate a contiguous chunk of memory and copy over the PollItem structs
    # to this block.
    def clean
      if @dirty
        @store = FFI::MemoryPointer.new @element_size, @items.size, false

        # copy over
        offset = 0
        @items.each do |item|
          LibC.memcpy(@store + offset, item, @element_size)
          offset += @element_size
        end

        @dirty = false
      end
    end

  end # class PollItems
end # module ZMQ

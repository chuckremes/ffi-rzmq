require 'forwardable'
require 'ostruct'

module ZMQ
  class PollItem
    extend Forwardable

    def_delegators :@poll_item, :pointer, :readable?, :writable?
    attr_accessor :pollable, :poll_item

    def initialize(pointer = nil)
      @poll_item = pointer ? LibZMQ::PollItem.new(pointer) : LibZMQ::PollItem.new
    end

    def self.from_pollable(pollable)
      item = self.new
      item.pollable = pollable
      case
      when pollable.respond_to?(:socket)
        item.socket = pollable.socket
      when pollable.respond_to?(:fileno)
        item.fd = pollable.fileno
      when pollable.respond_to?(:io)
        item.fd = pollable.io.fileno
      end
      item
    end

    def socket=(arg)
      @poll_item[:socket] = arg
    end

    def fd=(arg)
      @poll_item[:fd] = arg
    end

    def events=(arg)
      @poll_item[:events] = arg
    end

    def events
      @poll_item[:events]
    end
  end

  class PollItems
    include Enumerable
    extend  Forwardable

    def_delegators :@pollables, :size, :empty?

    def initialize
      @pollables  = {}
      @item_size  = LibZMQ::PollItem.size
      @item_store = nil
    end

    def address
      clean
      @item_store
    end

    def get pollable
      return unless entry = @pollables[pollable]
      clean
      pointer = @item_store + (@item_size * entry.index)
      item = ZMQ::PollItem.new(pointer)
      item.pollable = pollable
      item
    end
    alias :[] :get

    def <<(poll_item)
      @dirty = true
      @pollables[poll_item.pollable] = OpenStruct.new(index: size, data: poll_item)
    end
    alias :push :<<

    def delete pollable
      if @pollables.delete(pollable)
        found = @dirty = true
        clean
      else
        found = false
      end
      found
    end

    def each &blk
      clean
      @pollables.each do |pollable, _|
        yield get(pollable)
      end
    end

    def inspect
      clean
      str = ""
      each { |item| str << "ptr [#{item[:socket]}], events [#{item[:events]}], revents [#{item[:revents]}], " }
      str.chop.chop
    end

    def to_s; inspect; end

    private

    # Allocate a contiguous chunk of memory and copy over the PollItem structs
    # to this block. Note that the old +@store+ value goes out of scope so when
    # it is garbage collected that native memory should be automatically freed.
    def clean
      if @dirty
        @item_store = FFI::MemoryPointer.new @item_size, size, true

        offset = 0
        @pollables.each_with_index do |(pollable, entry), index|
          entry.index = index
          LibC.memcpy(@item_store + offset, entry.data.pointer, @item_size)
          offset += @item_size
        end

        @dirty = false
      end
    end

  end # class PollItems
end # module ZMQ

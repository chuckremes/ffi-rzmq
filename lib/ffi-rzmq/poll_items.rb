require 'forwardable'
require 'ostruct'

module ZMQ
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
      item = ZMQ::PollItem.from_pointer(pointer)
      item.pollable = pollable
      item
    end
    alias :[] :get

    def <<(poll_item)
      @dirty = true
      @pollables[poll_item.pollable] = OpenStruct.new(:index => size, :data => poll_item)
    end
    alias :push :<<

    def delete pollable
      if @pollables.delete(pollable)
        @dirty = true
        clean
        true
      else
        false
      end
    end

    def each &blk
      clean
      @pollables.each_key do |pollable|
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

  end
end

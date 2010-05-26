
module ZMQ

  ZMQ_POLL_STR = 'zmq_poll'.freeze

  class Poller
    include ZMQ::Util

    attr_reader :readables, :writables

    def initialize
      @items = ZMQ::PollItems.new
      @sockets = []
      @readables = []
      @writables = []
    end

    # Checks each poll item for selectability based on the poll items'
    # registered +events+. Will block for up to +timeout+ milliseconds
    # A millisecond is 1/1000 of a second, so to block for 1 second
    # pass the value "1000" to #poll.
    #
    # Pass "-1" or +:blocking+ for +timeout+ for this call to block
    # indefinitely.
    #
    # May raise a ZMQ::PollError exception. This occurs when one of the
    # registered sockets belongs to an application thread in another
    # Context.
    #
    def poll timeout = :blocking
      unless @items.empty?
        timeout = adjust timeout
        items_triggered = LibZMQ.zmq_poll @items.address, @items.size, timeout
        error_check ZMQ_POLL_STR, items_triggered >= 0 ? 0 : items_triggered
        update_selectables
        items_hash
      else
        {}
      end
    end

    # The non-blocking version of #poll. See the #poll description for
    # potential exceptions.
    #
    # May raise a ZMQ::PollError exception. This occurs when one of the
    # registered sockets belongs to an application thread in another
    # Context.
    #
    def poll_nonblock
      poll 0
    end

    # Register the +sock+ for +events+. This method is idempotent meaning
    # it can be called multiple times with the same data and the socket
    # will only get registered at most once. Calling multiple times with
    # different values for +events+ will OR the event information together.
    #
    # Does not raise any exceptions.
    #
    def register sock = nil, events = ZMQ::POLLIN | ZMQ::POLLOUT, fd = 0
      return unless sock || !fd.zero?

      @poll_items_dirty = true
      item = @items.get(@sockets.index(sock))

      unless item
        @sockets << sock
        item = LibZMQ::PollItem.new

        case sock
        when ZMQ::Socket, Socket
          item[:socket] = sock.socket
          item[:fd] = 0
        else
          item[:socket] = 0
          item[:fd] = fd
        end
      end

      item[:events] |= events

      @items << item
    end

    # A helper method to register a +sock+ as readable events only.
    #
    def register_readable sock
      register sock, ZMQ::POLLIN, 0
    end

    # A helper method to register a +sock+ for writable events only.
    #
    def register_writable sock
      register sock, ZMQ::POLLOUT, 0
    end

    def deregister sock
      if index = @sockets.index(sock)
        @items.delete_at index
        @sockets.delete sock
      end
    end
    
    def size(); @items.size; end
    
    def inspect
      str = ""
      @items.each { |item|  str << "#{item.inspect}, "}
      str.chop.chop
    end


    private

    def items_hash
      hsh = {}

      @items.each_with_index do |poll_item, i|
        hsh[@sockets[i]] = poll_item
      end

      hsh
    end

    def update_selectables
      @readables.clear
      @writables.clear

      @items.each_with_index do |poll_item, i|
        @readables << @sockets[i] if poll_item.readable?
        @writables << @sockets[i] if poll_item.writable?
      end
    end

    # Convert the timeout value to something usable by
    # the library.
    #
    # -1 or :blocking should be converted to -1.
    #
    # Users will pass in values measured as
    # milliseconds, so we need to convert that value to
    # microseconds for the library.
    def adjust timeout
      if :blocking == timeout || -1 == timeout
        -1
      else
        timeout *= 1000
      end
    end
  end

end # module ZMQ

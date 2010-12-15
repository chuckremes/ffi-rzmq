
module ZMQ

  ZMQ_POLL_STR = 'zmq_poll'.freeze

  class Poller
    include ZMQ::Util

    attr_reader :readables, :writables

    def initialize
      @items = ZMQ::PollItems.new
      @raw_to_socket = {}
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
    def register sock, events = ZMQ::POLLIN | ZMQ::POLLOUT, fd = 0
      return unless sock || !fd.zero? || !events.zero?

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

        @raw_to_socket[item[:socket].address] = sock
        @items << item
      end
      
      item[:events] |= events
    end

    # Deregister the +sock+ for +events+.
    #
    # Does not raise any exceptions.
    #
    def deregister sock, events, fd = 0
      return unless sock || !fd.zero?

      item = @items.get(@sockets.index(sock))

      if item
        # change the value in place
        item[:events] ^= events

        delete sock if item[:events].zero?
      end
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

    # A helper method to deregister a +sock+ for readable events.
    #
    def deregister_readable sock
      deregister sock, ZMQ::POLLIN, 0
    end

    # A helper method to deregister a +sock+ for writable events.
    #
    def deregister_writable sock
      deregister sock, ZMQ::POLLOUT, 0
    end

    # Deletes the +sock+ for all subscribed events.
    #
    def delete sock
      if index = @sockets.index(sock)
        @items.delete_at index
        @sockets.delete sock
        @raw_to_socket.delete sock.socket
      end
    end

    def size(); @items.size; end

    def inspect
      @items.inspect
    end

    def to_s(); inspect; end


    private

    def items_hash
      hsh = {}

      @items.each do |poll_item|
        hsh[@raw_to_socket[poll_item[:socket].address]] = poll_item
      end

      hsh
    end

    def update_selectables
      @readables.clear
      @writables.clear

      @items.each do |poll_item|
        @readables << @raw_to_socket[poll_item[:socket].address] if poll_item.readable?
        @writables << @raw_to_socket[poll_item[:socket].address] if poll_item.writable?
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
        (timeout * 1000).to_i
      end
    end
  end

end # module ZMQ

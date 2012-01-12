
module ZMQ

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

    # Checks each registered socket for selectability based on the poll items'
    # registered +events+. Will block for up to +timeout+ milliseconds
    # A millisecond is 1/1000 of a second, so to block for 1 second
    # pass the value "1000" to #poll.
    #
    # Pass "-1" or +:blocking+ for +timeout+ for this call to block
    # indefinitely.
    #
    # This method will return *immediately* when there are no registered
    # sockets. In that case, the +timeout+ parameter is not honored. To
    # prevent a CPU busy-loop, the caller of this method should detect
    # this possible condition (via #size) and throttle the call
    # frequency.
    #
    # Returns 0 when there are no registered sockets that are readable
    # or writable. 
    # 
    # Return 1 (or greater) to indicate the number of readable or writable
    # sockets. These sockets should be processed using the #readables and
    # #writables accessors.
    #
    # Returns -1 when there is an error. Use ZMQ::Util.errno to get the related
    # error number.
    #
    def poll timeout = :blocking
      unless @items.empty?
        timeout = adjust timeout
        items_triggered = LibZMQ.zmq_poll @items.address, @items.size, timeout
        
        if Util.resultcode_ok?(items_triggered)
          update_selectables
        end
        
        items_triggered
      else
        0
      end
    end

    # The non-blocking version of #poll. See the #poll description for
    # potential exceptions.
    #
    # May return -1 when an error is encounted. Check ZMQ::Util.errno
    # to determine the underlying cause.
    #
    def poll_nonblock
      poll 0
    end

    # Register the +sock+ for +events+. This method is idempotent meaning
    # it can be called multiple times with the same data and the socket
    # will only get registered at most once. Calling multiple times with
    # different values for +events+ will OR the event information together.
    #
    def register sock, events = ZMQ::POLLIN | ZMQ::POLLOUT, fd = 0
      return false if (sock.nil? && fd.zero?) || events.zero?

      item = @items.get(@sockets.index(sock))

      unless item
        @sockets << sock
        item = LibZMQ::PollItem.new

        if sock.kind_of?(ZMQ::Socket) || sock.kind_of?(Socket)
          item[:socket] = sock.socket
          item[:fd] = 0
        else
          item[:socket] = FFI::MemoryPointer.new(0)
          item[:fd] = fd
        end

        @raw_to_socket[item.socket.address] = sock
        @items << item
      end

      item[:events] |= events
    end

    # Deregister the +sock+ for +events+. When there are no events left,
    # this also deletes the socket from the poll items.
    #
    def deregister sock, events, fd = 0
      return unless sock || !fd.zero?

      item = @items.get(@sockets.index(sock))

      if item && (item[:events] & events) > 0
        # change the value in place
        item[:events] ^= events

        delete sock if item[:events].zero?
        true
      else
        false
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

    # Deletes the +sock+ for all subscribed events. Called internally
    # when a socket has been deregistered and has no more events
    # registered anywhere.
    #
    # Can also be called directly to remove the socket from the polling
    # array.
    #
    def delete sock
      unless (size = @sockets.size).zero?
        @sockets.delete_if { |socket| socket.socket.address == sock.socket.address }
        socket_deleted = size != @sockets.size

        item_deleted = @items.delete sock

        raw_deleted = @raw_to_socket.delete(sock.socket.address)

        socket_deleted && item_deleted && raw_deleted
        
      else
        false
      end
    end

    def size(); @items.size; end

    def inspect
      @items.inspect
    end

    def to_s(); inspect; end


    private

    def items_hash hash
      @items.each do |poll_item|
        hash[@raw_to_socket[poll_item.socket.address]] = poll_item
      end
    end

    def update_selectables
      @readables.clear
      @writables.clear

      @items.each do |poll_item|
        #FIXME: spec for sockets *and* file descriptors
        if poll_item.readable?
          @readables << (poll_item.socket.address.zero? ? poll_item.fd : @raw_to_socket[poll_item.socket.address])
        end
        
        if poll_item.writable?
          @writables << (poll_item.socket.address.zero? ? poll_item.fd : @raw_to_socket[poll_item.socket.address])
        end
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
    if LibZMQ.version2?
      def adjust timeout
        if :blocking == timeout || -1 == timeout
          -1
        else
          (timeout * 1000).to_i
        end
      end
    else
      # version3 changed units from microseconds to milliseconds
      def adjust timeout
        if :blocking == timeout || -1 == timeout
          -1
        else
          timeout.to_i
        end
      end
    end
  end

end # module ZMQ

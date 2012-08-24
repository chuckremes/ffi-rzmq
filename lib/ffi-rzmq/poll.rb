require 'forwardable'

module ZMQ

  class Poller
    extend Forwardable

    def_delegators :@poll_items, :size, :inspect
    attr_reader :readables, :writables

    def initialize
      @poll_items = ZMQ::PollItems.new
      @key_to_pollable = {}
      @pollables = []
      @readables = []
      @writables = []
    end

    # Checks each registered socket for selectability based on the poll items'
    # registered +events+. Will block for up to +timeout+ milliseconds.
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
      unless @poll_items.empty?
        timeout = adjust timeout
        items_triggered = LibZMQ.zmq_poll @poll_items.address, @poll_items.size, timeout

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

    # Register the +pollable+ for +events+. This method is idempotent meaning
    # it can be called multiple times with the same data and the socket
    # will only get registered at most once. Calling multiple times with
    # different values for +events+ will OR the event information together.
    #
    def register pollable, events = ZMQ::POLLIN | ZMQ::POLLOUT
      return false if pollable.nil? || events.zero?

      unless item = @poll_items.get(@pollables.index(pollable))
        @pollables << pollable

        item = LibZMQ::PollItem.new
        case
        when pollable.respond_to?(:socket)
          item[:socket], key = pollable.socket, pollable.socket.address
        when pollable.respond_to?(:fileno)
          item[:fd], key = pollable.fileno, pollable.fileno
        end

        @key_to_pollable[key] = pollable
        @poll_items << item
      end

      item[:events] |= events
    end

    # Deregister the +sock+ for +events+. When there are no events left,
    # this also deletes the socket from the poll items.
    #
    def deregister pollable, events
      return unless pollable

      item = @poll_items.get(@pollables.index(pollable))

      if item && (item[:events] & events) > 0
        # change the value in place
        item[:events] ^= events

        delete pollable if item[:events].zero? || (pollable.respond_to?(:socket) && pollable.socket.nil?)
        true
      else
        false
      end
    end

    # A helper method to register a +pollable+ as readable events only.
    #
    def register_readable pollable
      register pollable, ZMQ::POLLIN
    end

    # A helper method to register a +pollable+ for writable events only.
    #
    def register_writable pollable
      register pollable, ZMQ::POLLOUT
    end

    # A helper method to deregister a +pollable+ for readable events.
    #
    def deregister_readable pollable
      deregister pollable, ZMQ::POLLIN
    end

    # A helper method to deregister a +pollable+ for writable events.
    #
    def deregister_writable pollable
      deregister pollable, ZMQ::POLLOUT
    end

    # Deletes the +sock+ for all subscribed events. Called internally
    # when a socket has been deregistered and has no more events
    # registered anywhere.
    #
    # Can also be called directly to remove the socket from the polling
    # array.
    #
    # Sockets must be deleted before they are closed otherwise there is
    # no way to remove it from the polled items array. Attempting to
    # delete a closed socket triggers a very slow code path to figure
    # out which socket should be deleted.
    #
    def delete pollable
      size = @pollables.size
      return false if size.zero?

      case
      when pollable.respond_to?(:socket)
        if pollable.socket.nil?
          # slow code path! need to iterate through all sockets in the
          # poll items array to figure out which one has been closed
          slow_path_delete(pollable)
        else
          @pollables.delete_if { |p| p.socket.address == pollable.socket.address }
          socket_deleted = size != @pollables.size
          item_deleted = @poll_items.delete(pollable)
          raw_deleted  = @key_to_pollable.delete(pollable.socket.address)
          socket_deleted && item_deleted && raw_deleted
        end
      when pollable.respond_to?(:fileno)
        @pollables.delete_if { |p| p.fileno == pollable.fileno }
        socket_deleted = size != @pollables.size
        item_deleted = @poll_items.delete(pollable)
        raw_deleted = @key_to_pollable.delete(pollable.fileno)
        socket_deleted && item_deleted && raw_deleted
      end
    end

    def to_s inspect; end

    private

    def update_selectables
      @readables.clear
      @writables.clear

      @poll_items.each do |poll_item|
        address = poll_item.socket.address
        key = address.zero? ? poll_item.fd : address

        @readables << @key_to_pollable[key] if poll_item.readable?
        @writables << @key_to_pollable[key] if poll_item.writable?
      end
    end

    # Retrieves each socket from the PollItems array. If the item
    # cannot be matched to an element of the sockets array, we
    # delete that item from PollItems and do some clean up.
    def slow_path_delete pollable
      @pollables.delete pollable
      @poll_items.each_with_index do |poll_item, index|
        found = @pollables.find { |p| p.socket.address == poll_item.socket.address }

        # puts poll_item, index, found

        unless found
          @key_to_pollable.delete(poll_item.socket.address)
          @poll_items.delete_at(index)
          break true
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


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

    def poll timeout_in_usecs = -1
      unless @items.empty?
        result_code = LibZMQ.zmq_poll @items.address, @items.size, timeout_in_usecs
        error_check_poll result_code
        update_readable_writable
        items_hash
      else
        {}
      end
    end

    def poll_nonblock
      poll 0
    end

    # Register the +sock+ for +events+. This method is idempotent meaning
    # it can be called multiple times with the same data and the socket
    # will only get registered at most once. Calling multiple times with
    # different values for +events+ will OR the event information together.
    def register sock = nil, events = ZMQ::POLLIN | ZMQ::POLLOUT, fd = 0
      return unless sock

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

    def register_readable sock = nil
      register sock, ZMQ::POLLIN, 0
    end

    def register_writable sock = nil
      register sock, ZMQ::POLLOUT, 0
    end

    private

    def poll_items_c_array
      if @poll_items_dirty
        # more items were added, so let's map them to a C array
      else
        # no change to the items list; return previously mapped C array
        @c_array
      end
    end

    def items_hash
      hsh = {}

      @items.each_with_index do |poll_item, i|
        hsh[@sockets[i]] = poll_item
      end

      hsh
    end
    
    def update_readable_writable
      @readables.clear
      @writables.clear
      
      @items.each_with_index do |poll_item, i|
        @readables << @sockets[i] if poll_item.readable?
        @writables << @sockets[i] if poll_item.writable?
      end
    end
  end

end # module ZMQ


module ZMQ

  ZMQ_POLL_STR = 'zmq_poll'.freeze

  class Poller
    include ZMQ::Util

    def initialize
      @items = FFI::CArray.new LibZMQ::PollItem
      @sockets = []
    end

    def poll timeout_in_usecs = -1
      result_code = LibZMQ.zmq_poll @items.address, @items.size, timeout_in_usecs
      error_check_poll result_code
      items_hash
    end

    def poll_nonblock
      poll 0
    end

    # Register the +sock+ for +events+. This method is idempotent meaning
    # it can be called multiple times with the same data and the socket
    # will only get registered at most once. Calling multiple times with
    # different values for +events+ will OR the event information together.
    def register sock = nil, events = ZMQ::POLLIN | ZMQ::POLLOUT
      return unless socket

      item = get @sockets.index(sock)

      unless item
        @sockets << sock
        item = LibZMQ::PollItem.new
        case sock
        when Socket
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
      register sock, ZMQ::POLLIN, fd
    end

    def register_writable sock = nil
      register sock, ZMQ::POLLOUT, fd
    end

    private

    def items_hash
      hsh = {}
      i = 0
      @items.each do |poll_item|
        hsh[@sockets[i]] = poll_item
        i += 1
      end
      hsh
    end
  end

end # module ZMQ

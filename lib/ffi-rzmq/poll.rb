
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

    def register sock = nil, events = ZMQ::POLLIN | ZMQ::POLLOUT, fd = nil
      return unless socket || fd
      @sockets << sock
      item = LibZMQ::PollItem.new
      item[:socket] = sock.socket
      item[:fd] = fd
      item[:events] = events
      @items << item
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

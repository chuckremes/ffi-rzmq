require 'ffi'

module ZMQ

  class Context
    # initialize, socket

    def initialize app_threads, io_threads, flags
      @sockets ||= []
      @context_ptr = LibZMQ.zmq_init app_threads, io_threads, flags
    end

    def socket type
      Socket.new @context_ptr, type
    end
  end

  class Message
    def initialize message = nil
      @struct = LibZMQ::Msg_t.new

      if message
        #puts "new message [#{message}]"
        message = message.to_s
        data = FFI::MemoryPointer.from_string message
        result_code = LibZMQ.zmq_msg_init_size @struct, message.size
        #puts "Message init size err [#{result_code}]"
        result_code = LibZMQ.zmq_msg_init_data @struct, data, message.size, nil, nil
        #puts "Message data init err [#{result_code}]"
      else
        result_code = LibZMQ.zmq_msg_init @struct
        #puts "Empty Message err [#{result_code}]"
      end
    end

    def address
      @struct
    end

    def close
      LibZMQ.zmq_msg_close @struct
    end
  end

  class Socket

    def initialize context_ptr, type
      @socket = LibZMQ.zmq_socket context_ptr, type
    end

    # setsockopt, bind, connect, send, recv, close

    def setsockopt option_name, option_value, size = nil
      case option_value
      when String
        option_value_ptr = FFI::MemoryPointer.new :string
      when Numeric
        #puts "writing fixnum val [#{option_value}] to ptr"
        option_value_ptr = FFI::MemoryPointer.new :int
        #puts "new ptr"
        option_value_ptr.write_int option_value
        #puts "written"
        #puts "read, [#{option_value_ptr.read_int}]"
      end

      LibZMQ.zmq_setsockopt @socket, option_name, option_value_ptr, size || option_value.size
    end

    def bind address
      LibZMQ.zmq_bind @socket, address
    end

    def connect address
      LibZMQ.zmq_connect @socket, address
    end

    def send message, flags
      message = Message.new message
      LibZMQ.zmq_send @socket, message.address, flags
      message.close
    end


    def recv flags
      message = Message.new
      LibZMQ.zmq_recv @socket, message.address, flags
    end

  end

  # constants
  #  Socket types.
  PAIR = 0
  PUB = 1
  SUB = 2
  REQ = 3
  REP = 4
  XREQ = 5
  XREP = 6
  UPSTREAM = 7
  DOWNSTREAM = 8

  #  Socket options.
  HWM = 1
  LWM = 2
  SWAP = 3
  AFFINITY = 4
  IDENTITY = 5
  SUBSCRIBE = 6
  UNSUBSCRIBE = 7
  RATE = 8
  RECOVERY_IVL = 9
  MCAST_LOOP = 10
  SNDBUF = 11
  RCVBUF = 12
  RCVMORE = 13

  #  Send/recv options.
  NOBLOCK = 1
  SNDMORE = 2

  #******************************************************************************/
  #*  I/O multiplexing.                                                         */
  #******************************************************************************/

  POLLIN = 1
  POLLOUT = 2
  POLLERR = 4
end # module ZMQ


module ZMQ

  ZMQ_SETSOCKOPT_STR = 'zmq_setsockopt'.freeze
  ZMQ_BIND_STR = 'zmq_bind'.freeze
  ZMQ_CONNECT_STR = 'zmq_connect'.freeze
  ZMQ_SEND_STR = 'zmq_send'.freeze
  ZMQ_RECV_STR = 'zmq_recv'.freeze

  class Socket
    include ZMQ::Util

    def initialize context_ptr, type
      @socket = LibZMQ.zmq_socket context_ptr, type
    end

    def setsockopt option_name, option_value, size = nil
      case option_value
      when String
        option_value_ptr = FFI::MemoryPointer.from_string option_value
      when Numeric
        option_value_ptr = FFI::MemoryPointer.new :int
        option_value_ptr.write_int option_value
      end

      # FIXME: need to catch the case where the +type+ arg is invalid and raise an
      # EINVAL exception
      result_code = LibZMQ.zmq_setsockopt @socket, option_name, option_value_ptr, size || option_value.size
      error_check ZMQ_SETSOCKOPT_STR, result_code
    end

    def bind address
      result_code = LibZMQ.zmq_bind @socket, address
      error_check ZMQ_BIND_STR, result_code
    end

    def connect address
      result_code = LibZMQ.zmq_connect @socket, address
      error_check ZMQ_CONNECT_STR, result_code
    end

    def send message, flags
      message = Message.new message
      result_code = LibZMQ.zmq_send @socket, message.address, flags
      # FIXME: need to catch the case where +errno+ is EAGAIN; that should *NOT*
      # raise an exception but be returned as a result code for the upstream
      # application logic to handle
      error_check ZMQ_SEND_STR, result_code
      message.close
    end


    def recv flags
      message = Message.new
      result_code = LibZMQ.zmq_recv @socket, message.address, flags
      # FIXME: same situation as send; EAGAIN needs to be propogated up
      error_check ZMQ_RECV_STR, result_code
    end

  end

end # module ZMQ


module ZMQ

  ZMQ_MSG_INIT_SIZE_STR = 'zmq_msg_init_size'.freeze
  ZMQ_MSG_INIT_DATA_STR = 'zmq_msg_init_data'.freeze
  ZMQ_MSG_INIT_STR = 'zmq_msg_init'.freeze
  ZMQ_MSG_CLOSE_STR = 'zmq_msg_close'.freeze
  ZMQ_MSG_COPY_STR = 'zmq_msg_copy'.freeze
  ZMQ_MSG_MOVE_STR = 'zmq_msg_move'.freeze
  ZMQ_MSG_SIZE_STR = 'zmq_msg_size'.freeze

  class Message
    include ZMQ::Util

    def initialize message = nil
      @struct = LibZMQ::Msg_t.new

      if message
        #        case message
        #        when String, Bignum
        #          data = FFI::MemoryPointer.from_string message
        #        when Float
        #          data = FFI::MemoryPointer.new :float
        #          data.write_float message
        #        when Numeric
        #          # FIXME: need a performant way to determine if this numeric is
        #          # an int, long or long long so we can allocate and write to the
        #          # correct type of pointer;
        #          # by default, calling Fixnum.size will return 4 bytes for 32-bit
        #          # platforms and 8 bytes for 64-bit platforms
        #          case message.size
        #          when 4
        #            data = FFI::MemoryPointer.new :int
        #            data.write_int message
        #          when 8
        #            data = FFI::MemoryPointer.new :long_long
        #            data.write_long_long message
        #          else
        #            data = FFI::MemoryPointer.new :int
        #            data.write_int message
        #          end
        #        end

        data = FFI::MemoryPointer.from_string message.to_s
        result_code = LibZMQ.zmq_msg_init_size @struct, message.size
        error_check ZMQ_MSG_INIT_SIZE_STR, result_code
        result_code = LibZMQ.zmq_msg_init_data @struct, data, message.size, nil, nil
        error_check ZMQ_MSG_INIT_DATA_STR, result_code
      else
        result_code = LibZMQ.zmq_msg_init @struct
        error_check ZMQ_MSG_INIT_STR, result_code
      end
    end

    def address
      @struct
    end

    def copy source
      result_code = LibZMQ.zmq_msg_copy @struct, source.address
      error_check ZMQ_MSG_COPY_STR, result_code
    end

    def move source
      result_code = LibZMQ.zmq_msg_copy @struct, source.address
      error_check ZMQ_MSG_MOVE_STR, result_code
    end

    def size
      LibZMQ.zmq_msg_size @struct
    end

    def data
      data_ptr.read_string(size)
    end

    def close
      result_code = LibZMQ.zmq_msg_close @struct
      error_check ZMQ_MSG_CLOSE_STR, result_code
      @struct = nil
    end
    
    private
    
    def data_ptr
      LibZMQ.zmq_msg_data @struct
    end
  end

end # module ZMQ

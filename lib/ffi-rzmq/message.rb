
module ZMQ

  ZMQ_MSG_INIT_SIZE_STR = 'zmq_msg_init_size'.freeze
  ZMQ_MSG_INIT_DATA_STR = 'zmq_msg_init_data'.freeze
  ZMQ_MSG_INIT_STR = 'zmq_msg_init'.freeze
  ZMQ_MSG_CLOSE_STR = 'zmq_msg_close'.freeze
  ZMQ_MSG_COPY_STR = 'zmq_msg_copy'.freeze
  ZMQ_MSG_MOVE_STR = 'zmq_msg_move'.freeze
  ZMQ_MSG_SIZE_STR = 'zmq_msg_size'.freeze

  # By default the Socket class uses the +Message+ class for message handling. Need
  # a way to swap in this class if there is a desire to handle memory managment 
  # manually.
  class UnmanagedMessage
    include ZMQ::Util

    def initialize message = nil, length = nil
      @struct = LibZMQ::Msg.new

      if message
        data = FFI::MemoryPointer.from_string message.to_s

        result_code = LibZMQ.zmq_msg_init_data @struct, data, message.size, LibZMQ::MessageDeallocator, nil
        error_check ZMQ_MSG_INIT_DATA_STR, result_code
      else
        result_code = LibZMQ.zmq_msg_init @struct
        error_check ZMQ_MSG_INIT_STR, result_code
      end
    end

    # Provides the memory address of the +zmq_msg_t+ struct.
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

    # Provides the size of the data buffer for this +zmq_msg_t+ C struct
    def size
      LibZMQ.zmq_msg_size @struct
    end

    # Returns an FFI::MemoryPointer pointing to the data buffer.
    # This pointer should *never* be freed. It will automatically be freed
    # when the +message+ object goes out of scope and gets garbage
    # collected.
    def data
      FFI::MemoryPointer.new(LibZMQ.zmq_msg_data(@struct))
    end

    def data_as_string
      data.read_string(size)
    end
    
    # Manually release the message struct and its associated buffers.
    def close
      LibZMQ.zmq_msg_close struct
    end

  end # class UnmanagedMessage
  
  # The ruby equivalent of the +zmq_msg_t+ C struct. Access the underlying
  # memory buffer and the buffer size using the #data and #size methods
  # respectively.
  #
  # It is recommended that this class be subclassed to provide zero-copy
  # access to the underlying buffer.
  #
  # When you are done using the message object, just let it go out of
  # scope to release the memory. During the next garbage collection run
  # it will call the equivalent of #LibZMQ.zmq_msg_close to release
  # all buffers. Obviously, this automatic collection of message objects
  # comes at the price of a larger memory footprint (for the
  # finalizer proc object) and lower performance.
  #
  #  class MyMessage < Message
  #    class MyStruct < FFI::Struct
  #      layout :field1, :long,
  #             :field2, :long_long,
  #             :field3, :string
  #    end
  #
  #    def initialize original_message
  #      @data = MyStruct.new original_message.data
  #      @size = original_message.size
  #    end
  #
  #    def field1
  #      @field1 ||= @data[:field1].read_long
  #    end
  #
  #    def field2
  #      @field2 ||= @data[:field2].read_long_long
  #    end
  #
  #    def field3
  #      # assumes string is null-terminated (i.e. C string)
  #      @field3 ||= @data[:field3].read_string_to_null
  #    end
  # ---
  #
  #  message = MyMessage.new socket.recv
  #  puts "field1 is #{message.field1}"
  #
  
  class Message < UnmanagedMessage
    def initialize message = nil, length = nil
      super
      
      define_finalizer
    end
    
    # Has no effect. This class has automatic memory management.
    def close() end
    
    private
    
    def define_finalizer
      ObjectSpace.define_finalizer self, self.class.close(@struct)
    end

    # Message finalizer
    # Note that there is no error checking for the call to #zmq_msg_close.
    # This is intentional. Since this code runs as a finalizer, there is no
    # way to catch a raised exception anywhere near where the error actually
    # occurred in the code, so we just ignore deallocation failures here.
    def self.close struct
      proc {
        # release the data buffer
        LibZMQ.zmq_msg_close struct
      }
    end
  end # class Message

end # module ZMQ

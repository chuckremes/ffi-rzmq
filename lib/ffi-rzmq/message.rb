
module ZMQ

  ZMQ_MSG_INIT_SIZE_STR = 'zmq_msg_init_size'.freeze
  ZMQ_MSG_INIT_DATA_STR = 'zmq_msg_init_data'.freeze
  ZMQ_MSG_INIT_STR = 'zmq_msg_init'.freeze
  ZMQ_MSG_CLOSE_STR = 'zmq_msg_close'.freeze
  ZMQ_MSG_COPY_STR = 'zmq_msg_copy'.freeze
  ZMQ_MSG_MOVE_STR = 'zmq_msg_move'.freeze
  ZMQ_MSG_SIZE_STR = 'zmq_msg_size'.freeze

  # Call #close when done with this object to release buffers.
  #
  # When passing in a +message+ and +length+, the data is handed off to
  # to the message structure via a pointer. This provides a zero-copy
  # transmission facility for data buffers. 
  #
  # Note that by handing the message over to this class, it now owns the
  # buffer and its data. After calling #close on this object, it will
  # release those buffers; don't try to access the data again or hilarity
  # will ensue.
  # (Not really zero-copy yet. See FIXME note in the code.)
  class UnmanagedMessage
    include ZMQ::Util

    def initialize message = nil, length = nil
      # allocate our own pointer so that we can tell it to *not* zero out
      # the memory; it's pointless work since the library is going to 
      # overwrite it anyway.
      @pointer = FFI::MemoryPointer.new LibZMQ::Msg.size, 1, false
      @struct = LibZMQ::Msg.new @pointer

      if message
        # FIXME: not really zero-copy since #from_string copies the data to
        # native memory behind the scenes. The intention of this constructor is to
        # take in a pointer and its length and just pass it on to the Lib 
        # directly.
        # Strings require an extra byte to contain the null byte (C string)
        data_buffer = LibC.malloc message.size + 1
        data_buffer.put_string 0, message

        result_code = LibZMQ.zmq_msg_init_data @struct.pointer, data_buffer, message.size, LibZMQ::MessageDeallocator, nil
        #result_code = LibZMQ.zmq_msg_init_data @struct.pointer, data_buffer, message.size, nil, nil
        error_check ZMQ_MSG_INIT_DATA_STR, result_code
      else
        # initialize an empty message structure to receive a message
        result_code = LibZMQ.zmq_msg_init @struct
        error_check ZMQ_MSG_INIT_STR, result_code
      end
    end

    # Provides the memory address of the +zmq_msg_t+ struct.
    def address
      @struct.pointer
    end

    def copy source
      result_code = LibZMQ.zmq_msg_copy @struct.pointer, source.address
      error_check ZMQ_MSG_COPY_STR, result_code
    end

    def move source
      result_code = LibZMQ.zmq_msg_copy @struct.pointer, source.address
      error_check ZMQ_MSG_MOVE_STR, result_code
    end

    # Provides the size of the data buffer for this +zmq_msg_t+ C struct
    def size
      LibZMQ.zmq_msg_size @struct.pointer
    end

    # Returns a pointer to the data buffer.
    # This pointer should *never* be freed. It will automatically be freed
    # when the +message+ object goes out of scope and gets garbage
    # collected.
    def data
      LibZMQ.zmq_msg_data @struct.pointer
    end

    # Returns the data buffer as a string. The last byte is chopped off because
    # it should be the null byte. That isn't necessary for a ruby string.
    #
    # Note: If this is binary data, it won't print very prettily.
    def data_as_string
      data.read_string(size)#.chop!
    end
    
    # Manually release the message struct and its associated buffers.
    def close
      LibZMQ.zmq_msg_close @struct.pointer
      @pointer.free
      @struct = nil
    end

  end # class UnmanagedMessage
  
  # The ruby equivalent of the +zmq_msg_t+ C struct. Access the underlying
  # memory buffer and the buffer size using the #data and #size methods
  # respectively.
  #
  # It is recommended that this class be subclassed to provide zero-copy
  # access to the underlying buffer. The subclass can then be passed into
  # to the +ZMQ::Socket++ constructor as part of the +opts+ hash. All 
  # incoming and outgoing buffers for that socket will be wrapped by 
  # that subclass for easy access to the data.
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
    
    # Has no effect. This class has automatic memory management via a
    # finalizer.
    def close() end
    
    private
    
    def define_finalizer
      ObjectSpace.define_finalizer(self, self.class.close(@struct, @pointer))
    end

    # Message finalizer
    # Note that there is no error checking for the call to #zmq_msg_close.
    # This is intentional. Since this code runs as a finalizer, there is no
    # way to catch a raised exception anywhere near where the error actually
    # occurred in the code, so we just ignore deallocation failures here.
    def self.close struct, pointer
      Proc.new do
        # release the data buffer
        LibZMQ.zmq_msg_close struct.pointer
        pointer.free
        struct = nil
      end
    end
  end # class Message

end # module ZMQ

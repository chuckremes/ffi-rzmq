
module ZMQ

  ZMQ_MSG_INIT_SIZE_STR = 'zmq_msg_init_size'.freeze
  ZMQ_MSG_INIT_DATA_STR = 'zmq_msg_init_data'.freeze
  ZMQ_MSG_INIT_STR = 'zmq_msg_init'.freeze
  ZMQ_MSG_CLOSE_STR = 'zmq_msg_close'.freeze
  ZMQ_MSG_COPY_STR = 'zmq_msg_copy'.freeze
  ZMQ_MSG_MOVE_STR = 'zmq_msg_move'.freeze
  ZMQ_MSG_SIZE_STR = 'zmq_msg_size'.freeze

  # The constructor optionally takes a string as an argument. It will
  # copy this string to native memory in preparation for transmission.
  # So, don't pass a string unless you intend to send it. Internally it
  # calls #copy_in_string.
  #
  # Call #close to release buffers when you have *not* passed this on
  # to Socket#send. That method calls #close on your behalf.
  #
  # (This class is not really zero-copy. Ruby makes this near impossible
  # since Ruby objects can be relocated in memory by the GC at any
  # time. There is no way to peg them to native memory or have them
  # use non-movable native memory as backing store.)
  #
  # Message represents ruby equivalent of the +zmq_msg_t+ C struct.
  # Access the underlying memory buffer and the buffer size using the
  # #data and #size methods respectively.
  #
  # It is recommended that this class be composed inside another class for
  # access to the underlying buffer. The outer wrapper class can provide
  # nice accessors for the information in the data buffer; a clever
  # implementation can probably lazily encode/decode the data buffer
  # on demand. Lots of protocols send more information than is strictly
  # necessary, so only decode (copy from the 0mq buffer to Ruby) that
  # which is necessary.
  #
  # When you are done using a *received* message object, call #close to
  # release the associated buffers.
  #
  # As noted above, for sent objects the underlying library will call close
  # for you.
  #
  #  class MyMessage
  #    class Layout < FFI::Struct
  #      layout :value1, :uint8,
  #             :value2, :uint64,
  #             :value3, :uint32,
  #             :value4, [:char, 30]
  #    end
  #
  #    def initialize msg_struct = nil
  #      if msg_struct
  #        @msg_t = msg_struct
  #        @data = Layout.new(@msg_t.data)
  #      else
  #        @pointer = FFI::MemoryPointer.new :byte, Layout.size, true
  #        @data = Layout.new @pointer
  #      end
  #    end
  #
  #    def size() @size = @msg_t.size; end
  #
  #    def value1
  #      @data[:value1]
  #    end
  #
  #    def value4
  #      @data[:value4].to_ptr.read_string
  #    end
  #
  #    def value1=(val)
  #      @data[:value1] = val
  #    end
  #
  #    def create_sendable_message
  #      msg = Message.new
  #      msg.copy_in_bytes @pointer, Layout.size
  #    end
  #
  #
  #  message = Message.new
  #  successful_read = socket.recv message
  #  message = MyMessage.new message if successful_read
  #  puts "value1 is #{message.value1}"
  #
  class Message
    include ZMQ::Util

    def initialize message = nil
      @state = :uninitialized

      # allocate our own pointer so that we can tell it to *not* zero out
      # the memory; it's pointless work since the library is going to
      # overwrite it anyway.
      @pointer = FFI::MemoryPointer.new LibZMQ::Msg.size, 1, false
      @struct = LibZMQ::Msg.new @pointer

      if message
        copy_in_string message
      else
        # initialize an empty message structure to receive a message
        result_code = LibZMQ.zmq_msg_init @pointer
        error_check ZMQ_MSG_INIT_STR, result_code
      end
    end

    # Makes a copy of the ruby +string+ into a native memory buffer so
    # that libzmq can send it. The underlying library will handle
    # deallocation of the native memory buffer.
    #
    # Can only be initialized via #copy_in_string or #copy_in_bytes once.
    #
    # Can raise a MessageError when #copy_in_string or #copy_in_bytes is
    # called multiple times on the same instance. 
    #
    def copy_in_string string
      string_size = string.respond_to?(:bytesize) ? string.bytesize : string.size
      copy_in_bytes string, string_size if string
    end

    # Makes a copy of +len+ bytes from the ruby string +bytes+. Library
    # handles deallocation of the native memory buffer.
    #
    # Can only be initialized via #copy_in_string or #copy_in_bytes once.
    #
    # Can raise a MessageError when #copy_in_string or #copy_in_bytes is
    # called multiple times on the same instance. 
    #
    def copy_in_bytes bytes, len
      raise MessageError.new "#{self}", -1, -1, "This object cannot be reused; allocate a new one!" if initialized?

      data_buffer = LibC.malloc len
      # writes the exact number of bytes, no null byte to terminate string
      data_buffer.write_string bytes, len

      # use libC to call free on the data buffer; earlier versions used an
      # FFI::Function here that called back into Ruby, but Rubinius won't 
      # support that and there are issues with the other runtimes too
      result_code = LibZMQ.zmq_msg_init_data @pointer, data_buffer, len, LibC::Free, nil

      error_check ZMQ_MSG_INIT_DATA_STR, result_code
      @state = :initialized
    end

    # Provides the memory address of the +zmq_msg_t+ struct. Used mostly for
    # passing to other methods accessing the underlying library that
    # require a real data address.
    #
    def address
      @pointer
    end
    alias :pointer :address

    def copy source
      result_code = LibZMQ.zmq_msg_copy @pointer, source.address
      error_check ZMQ_MSG_COPY_STR, result_code
      @state = :initialized
    end

    def move source
      result_code = LibZMQ.zmq_msg_copy @pointer, source.address
      error_check ZMQ_MSG_MOVE_STR, result_code
      @state = :initialized
    end

    # Provides the size of the data buffer for this +zmq_msg_t+ C struct.
    #
    def size
      LibZMQ.zmq_msg_size @pointer
    end

    # Returns a pointer to the data buffer.
    # This pointer should *never* be freed. It will automatically be freed
    # when the +message+ object goes out of scope and gets garbage
    # collected.
    #
    def data
      LibZMQ.zmq_msg_data @pointer
    end

    # Returns the data buffer as a string.
    #
    # Note: If this is binary data, it won't print very prettily.
    #
    def copy_out_string
      data.read_string(size)
    end

    # Manually release the message struct and its associated data
    # buffer.
    #
    # Only releases the buffer a single time. Subsequent calls are
    # no ops.
    #
    def close
      if @pointer
        LibZMQ.zmq_msg_close @pointer
        @pointer = nil
      end
    end


    private

    def initialized?(); :initialized == @state; end

  end # class Message



  # A subclass of #Message that includes finalizers for deallocating
  # native memory when this object is garbage collected. Note that on
  # certain Ruby runtimes the use of finalizers can add 10s of
  # microseconds of overhead for each message. The convenience comes
  # at a price.
  #
  # The constructor optionally takes a string as an argument. It will
  # copy this string to native memory in preparation for transmission.
  # So, don't pass a string unless you intend to send it. Internally it
  # calls #copy_in_string.
  #
  # Call #close to release buffers when you have *not* passed this on
  # to Socket#send. That method calls #close on your behalf.
  #
  # When you are done using a *received* message object, just let it go out of
  # scope to release the memory. During the next garbage collection run
  # it will call the equivalent of #LibZMQ.zmq_msg_close to release
  # all buffers. Obviously, this automatic collection of message objects
  # comes at the price of a larger memory footprint (for the
  # finalizer proc object) and lower performance. If you wanted blistering
  # performance, Ruby isn't there just yet.
  #
  # As noted above, for sent objects the underlying library will call close
  # for you.
  #
  class ManagedMessage < Message
    # Makes a copy of +len+ bytes from the ruby string +bytes+. Library
    # handles deallocation of the native memory buffer.
    #
    def copy_in_bytes bytes, len
      super
      
      # make sure we have a way to deallocate this memory if the object goes
      # out of scope
      define_finalizer
    end

    # Manually release the message struct and its associated data
    # buffer.
    #
    def close
      super
      remove_finalizer
    end


    private

    def define_finalizer
      ObjectSpace.define_finalizer(self, self.class.close(@pointer))
    end

    def remove_finalizer
      ObjectSpace.undefine_finalizer self
    end

    # Message finalizer
    # Note that there is no error checking for the call to #zmq_msg_close.
    # This is intentional. Since this code runs as a finalizer, there is no
    # way to catch a raised exception anywhere near where the error actually
    # occurred in the code, so we just ignore deallocation failures here.
    def self.close ptr
      Proc.new do
        # release the data buffer
        LibZMQ.zmq_msg_close ptr
      end
    end

  end # class ManagedMessage

end # module ZMQ

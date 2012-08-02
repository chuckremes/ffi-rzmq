
module ZMQ

  # The factory constructor optionally takes a string as an argument. It will
  # copy this string to native memory in preparation for transmission.
  # So, don't pass a string unless you intend to send it. Internally it
  # calls #copy_in_string.
  #
  # Call #close to release buffers when you are done with the data.
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
  #  received_message = Message.create
  #  if received_message
  #    rc = socket.recvmsg(received_message)
  #    if ZMQ::Util.resultcode_ok?(rc)
  #      puts "Message contained: #{received_message.copy_out_string}"
  #    else
  #      STDERR.puts "Error when receiving message: #{ZMQ::Util.error_string}"
  #    end
  #
  #
  # Define a custom layout for the data sent between 0mq peers.
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
    
    # Recommended way to create a standard message. A Message object is 
    # returned upon success, nil when allocation fails.
    #
    def self.create message = nil
      new(message) rescue nil
    end

    def initialize message = nil
      # allocate our own pointer so that we can tell it to *not* zero out
      # the memory; it's pointless work since the library is going to
      # overwrite it anyway.
      @pointer = FFI::MemoryPointer.new Message.msg_size, 1, false

      if message
        copy_in_string message
      else
        # initialize an empty message structure to receive a message
        result_code = LibZMQ.zmq_msg_init @pointer
        raise unless Util.resultcode_ok?(result_code)
      end
    end

    # Makes a copy of the ruby +string+ into a native memory buffer so
    # that libzmq can send it. The underlying library will handle
    # deallocation of the native memory buffer.
    #
    # Can only be initialized via #copy_in_string or #copy_in_bytes once.
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
    def copy_in_bytes bytes, len
      data_buffer = LibC.malloc len
      # writes the exact number of bytes, no null byte to terminate string
      data_buffer.write_string bytes, len

      # use libC to call free on the data buffer; earlier versions used an
      # FFI::Function here that called back into Ruby, but Rubinius won't 
      # support that and there are issues with the other runtimes too
      LibZMQ.zmq_msg_init_data @pointer, data_buffer, len, LibC::Free, nil
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
      LibZMQ.zmq_msg_copy @pointer, source
    end

    def move source
      LibZMQ.zmq_msg_move @pointer, source
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
      rc = 0
      
      if @pointer
        rc = LibZMQ.zmq_msg_close @pointer
        @pointer = nil
      end
      
      rc
    end
    
    # cache the msg size so we don't have to recalculate it when creating
    # each new instance
    @msg_size = LibZMQ::Msg.size
    
    def self.msg_size() @msg_size; end

  end # class Message
  
  if LibZMQ.version3?
    class Message
      # Version3 only
      #
      def get(property)
        LibZMQ.zmq_msg_get(@pointer, property)
      end
      
      # Version3 only
      #
      # Returns true if this message has additional parts coming.
      #
      def more?
        Util.resultcode_ok?(get(MORE))
      end
      
      def set(property, value)
        LibZMQ.zmq_msg_set(@pointer, property, value)
      end
    end
  end



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
      rc = super(bytes, len)
      
      # make sure we have a way to deallocate this memory if the object goes
      # out of scope
      define_finalizer
      rc
    end

    # Manually release the message struct and its associated data
    # buffer.
    #
    def close
      rc = super()
      remove_finalizer
      rc
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

    # cache the msg size so we don't have to recalculate it when creating
    # each new instance
    # need to do this again because ivars are not inheritable
    @msg_size = LibZMQ::Msg.size

  end # class ManagedMessage

end # module ZMQ

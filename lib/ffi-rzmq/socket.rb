
module ZMQ

  class Socket
    attr_reader :socket, :name

    # Allocates a socket of type +type+ for sending and receiving data.
    #
    # +type+ can be one of ZMQ::REQ, ZMQ::REP, ZMQ::PUB,
    # ZMQ::SUB, ZMQ::PAIR, ZMQ::PULL, ZMQ::PUSH, ZMQ::XREQ, ZMQ::REP,
    # ZMQ::DEALER or ZMQ::ROUTER.
    #
    # By default, this class uses ZMQ::Message for manual
    # memory management. For automatic garbage collection of received messages,
    # it is possible to override the :receiver_class to use ZMQ::ManagedMessage.
    #
    #  sock = Socket.create(Context.create, ZMQ::REQ, :receiver_class => ZMQ::ManagedMessage)
    #
    # Advanced users may want to replace the receiver class with their
    # own custom class. The custom class must conform to the same public API
    # as ZMQ::Message.
    #
    # Creation of a new Socket object can return nil when socket creation
    # fails.
    #
    #  if (socket = Socket.new(context.pointer, ZMQ::REQ))
    #    ...
    #  else
    #    STDERR.puts "Socket creation failed"
    #  end
    #
    def self.create context_ptr, type, opts = {:receiver_class => ZMQ::Message}
      new(context_ptr, type, opts) rescue nil
    end

    # To avoid rescuing exceptions, use the factory method #create for
    # all socket creation.
    #
    # Allocates a socket of type +type+ for sending and receiving data.
    #
    # +type+ can be one of ZMQ::REQ, ZMQ::REP, ZMQ::PUB,
    # ZMQ::SUB, ZMQ::PAIR, ZMQ::PULL, ZMQ::PUSH, ZMQ::XREQ, ZMQ::REP,
    # ZMQ::DEALER or ZMQ::ROUTER.
    #
    # By default, this class uses ZMQ::Message for manual
    # memory management. For automatic garbage collection of received messages,
    # it is possible to override the :receiver_class to use ZMQ::ManagedMessage.
    #
    #  sock = Socket.new(Context.new, ZMQ::REQ, :receiver_class => ZMQ::ManagedMessage)
    #
    # Advanced users may want to replace the receiver class with their
    # own custom class. The custom class must conform to the same public API
    # as ZMQ::Message.
    #
    # Creation of a new Socket object can raise an exception. This occurs when the
    # +context_ptr+ is null or when the allocation of the 0mq socket within the
    # context fails.
    #
    #  begin
    #    socket = Socket.new(context.pointer, ZMQ::REQ)
    #  rescue ContextError => e
    #    # error handling
    #  end
    #
    def initialize context_ptr, type, opts = {:receiver_class => ZMQ::Message}
      # users may override the classes used for receiving; class must conform to the
      # same public API as ZMQ::Message
      @receiver_klass = opts[:receiver_class]

      context_ptr = context_ptr.pointer if context_ptr.kind_of?(ZMQ::Context)

      if context_ptr.nil? || context_ptr.null?
        raise ContextError.new 'zmq_socket', 0, ETERM, "Context pointer was null"
      else
        @socket = LibZMQ.zmq_socket context_ptr, type
        if @socket && !@socket.null?
          @name = SocketTypeNameMap[type]
        else
          raise ContextError.new 'zmq_socket', 0, ETERM, "Socket pointer was null"
        end
      end

      @longlong_cache = @int_cache = nil
      @more_parts_array = []
      @option_lookup = []
      populate_option_lookup

      define_finalizer
    end

    # Set the queue options on this socket.
    #
    # Valid +name+ values that take a numeric +value+ are:
    #  ZMQ::HWM
    #  ZMQ::SWAP (version 2 only)
    #  ZMQ::AFFINITY
    #  ZMQ::RATE
    #  ZMQ::RECOVERY_IVL
    #  ZMQ::MCAST_LOOP (version 2 only)
    #  ZMQ::LINGER
    #  ZMQ::RECONNECT_IVL
    #  ZMQ::BACKLOG
    #  ZMQ::RECOVER_IVL_MSEC (version 2 only)
    #  ZMQ::RECONNECT_IVL_MAX (version 3 only)
    #  ZMQ::MAXMSGSIZE (version 3 only)
    #  ZMQ::SNDHWM (version 3 only)
    #  ZMQ::RCVHWM (version 3 only)
    #  ZMQ::MULTICAST_HOPS (version 3 only)
    #  ZMQ::RCVTIMEO (version 3 only)
    #  ZMQ::SNDTIMEO (version 3 only)
    #
    # Valid +name+ values that take a string +value+ are:
    #  ZMQ::IDENTITY (version 2/3 only)
    #  ZMQ::SUBSCRIBE
    #  ZMQ::UNSUBSCRIBE
    #
    # Returns 0 when the operation completed successfully.
    # Returns -1 when this operation failed.
    #
    # With a -1 return code, the user must check ZMQ::Util.errno to determine the
    # cause.
    #
    #  rc = socket.setsockopt(ZMQ::LINGER, 1_000)
    #  ZMQ::Util.resultcode_ok?(rc) ? puts("succeeded") : puts("failed")
    #
    def setsockopt name, value, length = nil
      if 1 == @option_lookup[name]
        length = 8
        pointer = LibC.malloc length
        pointer.write_long_long value

      elsif 0 == @option_lookup[name]
        length = 4
        pointer = LibC.malloc length
        pointer.write_int value

      elsif 2 == @option_lookup[name]
        # Strings are treated as pointers by FFI so we'll just pass it through
        length ||= value.size
        pointer = value

      end

      rc = LibZMQ.zmq_setsockopt @socket, name, pointer, length
      LibC.free(pointer) unless pointer.is_a?(String) || pointer.nil? || pointer.null?
      rc
    end

    # Convenience method for checking on additional message parts.
    #
    # Equivalent to calling Socket#getsockopt with ZMQ::RCVMORE.
    #
    # Warning: if the call to #getsockopt fails, this method will return
    # false and swallow the error.
    #
    #  message_parts = []
    #  message = Message.new
    #  rc = socket.recvmsg(message)
    #  if ZMQ::Util.resultcode_ok?(rc)
    #    message_parts << message
    #    while more_parts?
    #      message = Message.new
    #      rc = socket.recvmsg(message)
    #      message_parts.push(message) if resulcode_ok?(rc)
    #    end
    #  end
    #
    def more_parts?
      rc = getsockopt ZMQ::RCVMORE, @more_parts_array

      Util.resultcode_ok?(rc) ? @more_parts_array.at(0) : false
    end

    # Binds the socket to an +address+.
    #
    #  socket.bind("tcp://127.0.0.1:5555")
    #
    def bind address
      LibZMQ.zmq_bind @socket, address
    end

    # Connects the socket to an +address+.
    #
    #  rc = socket.connect("tcp://127.0.0.1:5555")
    #
    def connect address
      rc = LibZMQ.zmq_connect @socket, address
    end

    # Closes the socket. Any unprocessed messages in queue are sent or dropped
    # depending upon the value of the socket option ZMQ::LINGER.
    #
    # Returns 0 upon success *or* when the socket has already been closed.
    # Returns -1 when the operation fails. Check ZMQ::Util.errno for the error code.
    #
    #  rc = socket.close
    #  puts("Given socket was invalid!") unless 0 == rc
    #
    def close
      if @socket
        remove_finalizer
        rc = LibZMQ.zmq_close @socket
        @socket = nil
        release_cache
        rc
      else
        0
      end
    end

    # Queues the message for transmission. Message is assumed to conform to the
    # same public API as #Message.
    #
    # +flags+ may take two values:
    # * 0 (default) - blocking operation
    # * ZMQ::DONTWAIT - non-blocking operation
    # * ZMQ::SNDMORE - this message is part of a multi-part message
    #
    # Returns 0 when the message was successfully enqueued.
    # Returns -1 under two conditions.
    # 1. The message could not be enqueued
    # 2. When +flags+ is set with ZMQ::DONTWAIT and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check ZMQ::Util.errno to determine the
    # cause.
    #
    def sendmsg message, flags = 0
      __sendmsg__(@socket, message.address, flags)
    end

    # Helper method to make a new #Message instance out of the +string+ passed
    # in for transmission.
    #
    # +flags+ may be ZMQ::DONTWAIT and ZMQ::SNDMORE.
    #
    # Returns 0 when the message was successfully enqueued.
    # Returns -1 under two conditions.
    # 1. The message could not be enqueued
    # 2. When +flags+ is set with ZMQ::DONTWAIT and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check ZMQ::Util.errno to determine the
    # cause.
    #
    def send_string string, flags = 0
      message = Message.new string
      send_and_close message, flags
    end

    # Send a sequence of strings as a multipart message out of the +parts+
    # passed in for transmission. Every element of +parts+ should be
    # a String.
    #
    # +flags+ may be ZMQ::DONTWAIT.
    #
    # Returns 0 when the messages were successfully enqueued.
    # Returns -1 under two conditions.
    # 1. A message could not be enqueued
    # 2. When +flags+ is set with ZMQ::DONTWAIT and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check ZMQ::Util.errno to determine the
    # cause.
    #
    def send_strings parts, flags = 0
      send_multiple(parts, flags, :send_string)
    end

    # Send a sequence of messages as a multipart message out of the +parts+
    # passed in for transmission. Every element of +parts+ should be
    # a Message (or subclass).
    #
    # +flags+ may be ZMQ::DONTWAIT.
    #
    # Returns 0 when the messages were successfully enqueued.
    # Returns -1 under two conditions.
    # 1. A message could not be enqueued
    # 2. When +flags+ is set with ZMQ::DONTWAIT and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check ZMQ::Util.errno to determine the
    # cause.
    #
    def sendmsgs parts, flags = 0
      send_multiple(parts, flags, :sendmsg)
    end

    # Sends a message. This will automatically close the +message+ for both successful
    # and failed sends.
    #
    # Returns 0 when the message was successfully enqueued.
    # Returns -1 under two conditions.
    # 1. The message could not be enqueued
    # 2. When +flags+ is set with ZMQ::DONTWAIT and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check ZMQ::Util.errno to determine the
    # cause.
    #
    def send_and_close message, flags = 0
      rc = sendmsg message, flags
      message.close
      rc
    end

    # Dequeues a message from the underlying queue. By default, this is a blocking operation.
    #
    # +flags+ may take two values:
    #  0 (default) - blocking operation
    #  ZMQ::DONTWAIT - non-blocking operation
    #
    # Returns 0 when the message was successfully dequeued.
    # Returns -1 under two conditions.
    # 1. The message could not be dequeued
    # 2. When +flags+ is set with ZMQ::DONTWAIT and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check ZMQ::Util.errno to determine the
    # cause.
    #
    # The application code is responsible for handling the +message+ object lifecycle
    # when #recv returns an error code.
    #
    def recvmsg message, flags = 0
      #LibZMQ.zmq_recvmsg @socket, message.address, flags
      __recvmsg__(@socket, message.address, flags)
    end

    # Helper method to make a new #Message instance and convert its payload
    # to a string.
    #
    # +flags+ may be ZMQ::DONTWAIT.
    #
    # Returns 0 when the message was successfully dequeued.
    # Returns -1 under two conditions.
    # 1. The message could not be dequeued
    # 2. When +flags+ is set with ZMQ::DONTWAIT and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check ZMQ::Util.errno to determine the
    # cause.
    #
    # The application code is responsible for handling the +message+ object lifecycle
    # when #recv returns an error code.
    #
    def recv_string string, flags = 0
      message = @receiver_klass.new
      rc = recvmsg message, flags
      string.replace(message.copy_out_string) if Util.resultcode_ok?(rc)
      message.close
      rc
    end

    # Receive a multipart message as a list of strings.
    #
    # +flag+ may be ZMQ::DONTWAIT. Any other flag will be
    # removed.
    #
    def recv_strings list, flag = 0
      array = []
      rc = recvmsgs array, flag

      if Util.resultcode_ok?(rc)
        array.each do |message|
          list << message.copy_out_string
          message.close
        end
      end

      rc
    end

    # Receive a multipart message as an array of objects
    # (by default these are instances of Message).
    #
    # +flag+ may be ZMQ::DONTWAIT. Any other flag will be
    # removed.
    #
    def recvmsgs list, flag = 0
      flag = DONTWAIT if dontwait?(flag)

      message = @receiver_klass.new
      rc = recvmsg message, flag

      if Util.resultcode_ok?(rc)
        list << message

        # check rc *first*; necessary because the call to #more_parts? can reset
        # the zmq_errno to a weird value, so the zmq_errno that was set on the
        # call to #recv gets lost
        while Util.resultcode_ok?(rc) && more_parts?
          message = @receiver_klass.new
          rc = recvmsg message, flag

          if Util.resultcode_ok?(rc)
            list << message
          else
            message.close
            list.each { |msg| msg.close }
            list.clear
          end
        end
      else
        message.close
      end

      rc
    end

    # Should only be used for XREQ, XREP, DEALER and ROUTER type sockets. Takes
    # a +list+ for receiving the message body parts and a +routing_envelope+
    # for receiving the message parts comprising the 0mq routing information.
    #
    def recv_multipart list, routing_envelope, flag = 0
      parts = []
      rc = recvmsgs parts, flag

      if Util.resultcode_ok?(rc)
        routing = true
        parts.each do |part|
          if routing
            routing_envelope << part
            routing = part.size > 0
          else
            list << part
          end
        end
      end

      rc
    end

    # Get the options set on this socket.
    #
    # +name+ determines the socket option to request
    # +array+ should be an empty array; a result of the proper type
    # (numeric, string, boolean) will be inserted into
    # the first position.
    #
    # Valid +option_name+ values:
    #  ZMQ::RCVMORE - true or false
    #  ZMQ::HWM - integer
    #  ZMQ::SWAP - integer
    #  ZMQ::AFFINITY - bitmap in an integer
    #  ZMQ::IDENTITY - string
    #  ZMQ::RATE - integer
    #  ZMQ::RECOVERY_IVL - integer
    #  ZMQ::SNDBUF - integer
    #  ZMQ::RCVBUF - integer
    #  ZMQ::FD     - fd in an integer
    #  ZMQ::EVENTS - bitmap integer
    #  ZMQ::LINGER - integer measured in milliseconds
    #  ZMQ::RECONNECT_IVL - integer measured in milliseconds
    #  ZMQ::BACKLOG - integer
    #  ZMQ::RECOVER_IVL_MSEC - integer measured in milliseconds
    #  ZMQ::IPV4ONLY - integer
    #
    # Returns 0 when the operation completed successfully.
    # Returns -1 when this operation failed.
    #
    # With a -1 return code, the user must check ZMQ::Util.errno to determine the
    # cause.
    #
    #  # retrieve high water mark
    #  array = []
    #  rc = socket.getsockopt(ZMQ::HWM, array)
    #  hwm = array.first if ZMQ::Util.resultcode_ok?(rc)
    #
    def getsockopt name, array
      rc = __getsockopt__ name, array

      if Util.resultcode_ok?(rc) && (RCVMORE == name)
        # convert to boolean
        array[0] = 1 == array[0]
      end

      rc
    end

    # Convenience method for getting the value of the socket IDENTITY.
    #
    def identity
      array = []
      getsockopt IDENTITY, array
      array.at(0)
    end

    # Convenience method for setting the value of the socket IDENTITY.
    #
    def identity=(value)
      setsockopt IDENTITY, value.to_s
    end

    # Disconnect the socket from the given +endpoint+.
    #
    def disconnect(endpoint)
      LibZMQ.zmq_disconnect(socket, endpoint)
    end

    # Unbind the socket from the given +endpoint+.
    #
    def unbind(endpoint)
      LibZMQ.zmq_unbind(socket, endpoint)
    end


    private

    def send_multiple(parts, flags, method_name)
      if !parts || parts.empty?
        -1
      else
        flags = DONTWAIT if dontwait?(flags)
        rc = 0

        parts[0..-2].each do |part|
          rc = send(method_name, part, (flags | ZMQ::SNDMORE))
          break unless Util.resultcode_ok?(rc)
        end

        Util.resultcode_ok?(rc) ? send(method_name, parts[-1], flags) : rc
      end
    end

    def __getsockopt__ name, array
      # a small optimization so we only have to determine the option
      # type a single time; gives approx 5% speedup to do it this way.
      option_type = @option_lookup[name]

      value, length = sockopt_buffers option_type

      rc = LibZMQ.zmq_getsockopt @socket, name, value, length

      if Util.resultcode_ok?(rc)
        array[0] = if 1 == option_type
          value.read_long_long
        elsif 0 == option_type
          value.read_int
        elsif 2 == option_type
          value.read_string(length.read_int)
        end
      end

      rc
    end

    # Calls to ZMQ.getsockopt require us to pass in some pointers. We can cache and save those buffers
    # for subsequent calls. This is a big perf win for calling RCVMORE which happens quite often.
    # Cannot save the buffer for the IDENTITY.
    def sockopt_buffers option_type
      if 1 == option_type
        # int64_t or uint64_t
        @longlong_cache ||= alloc_pointer(:int64, 8)

      elsif 0 == option_type
        # int, 0mq assumes int is 4-bytes
        @int_cache ||= alloc_pointer(:int32, 4)

      elsif 2 == option_type
        # could be a string of up to 255 bytes, so allocate for worst case
        alloc_pointer(255, 255)

      else
        # uh oh, someone passed in an unknown option; return nil
        @int_cache ||= alloc_pointer(:int32, 4)
      end
    end

    def release_cache
      @longlong_cache = nil
      @int_cache = nil
    end

    def dontwait?(flags)
      (DONTWAIT & flags) == DONTWAIT
    end
    alias :noblock? :dontwait?

    def alloc_pointer(kind, length)
      pointer = FFI::MemoryPointer.new :size_t
      pointer.write_int(length)
      [FFI::MemoryPointer.new(kind), pointer]
    end

    def __sendmsg__(socket, address, flags)
      LibZMQ.zmq_sendmsg(socket, address, flags)
    end

    def __recvmsg__(socket, address, flags)
      LibZMQ.zmq_recvmsg(socket, address, flags)
    end

    def populate_option_lookup
      IntegerSocketOptions.each { |option| @option_lookup[option] = 0 }

      LongLongSocketOptions.each { |option| @option_lookup[option] = 1 }

      StringSocketOptions.each { |option| @option_lookup[option] = 2 }
    end

    # these finalizer-related methods cannot live in the CommonSocketBehavior
    # module; they *must* be in the class definition directly

    def define_finalizer
      ObjectSpace.define_finalizer(self, self.class.close(@socket, Process.pid))
    end

    def remove_finalizer
      ObjectSpace.undefine_finalizer self
    end

    def self.close socket, pid
      Proc.new { LibZMQ.zmq_close socket if Process.pid == pid }
    end
  end # Socket

end # module ZMQ

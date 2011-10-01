
module ZMQ

  module CommonSocketBehavior
    include ZMQ::Util

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

      unless context_ptr.null?
        @socket = LibZMQ.zmq_socket context_ptr, type
        if @socket && !@socket.null?
          @name = SocketTypeNameMap[type]
        else
          raise ContextError.new 'zmq_socket', 0, ETERM, "Socket pointer was null"
        end
      else
        raise ContextError.new 'zmq_socket', 0, ETERM, "Context pointer was null"
      end

      @sockopt_cache = {}

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
    #  ZMQ::RECONNECT_IVL_MAX (version 3/4 only)
    #  ZMQ::MAXMSGSIZE (version 3/4 only)
    #  ZMQ::SNDHWM (version 3/4 only)
    #  ZMQ::RCVHWM (version 3/4 only)
    #  ZMQ::MULTICAST_HOPS (version 3/4 only)
    #  ZMQ::RCVTIMEO (version 3/4 only)
    #  ZMQ::SNDTIMEO (version 3/4 only)
    #  ZMQ::RCVLABEL (version 3/4 only)
    #
    # Valid +name+ values that take a string +value+ are:
    #  ZMQ::IDENTITY (version 2/3 only)
    #  ZMQ::SUBSCRIBE
    #  ZMQ::UNSUBSCRIBE
    #
    # Returns 0 when the operation completed successfully.
    # Returns -1 when this operation failed.
    #
    # With a -1 return code, the user must check ZMQ.errno to determine the
    # cause.
    #
    #  rc = socket.setsockopt(ZMQ::LINGER, 1_000)
    #  ZMQ::Util.resultcode_ok?(rc) ? puts("succeeded") : puts("failed")
    #
    def setsockopt name, value, length = nil
      if long_long_option?(name)
        length = 8
        pointer = LibC.malloc length
        pointer.write_long_long value

      elsif int_option?(name)
        length = 4
        pointer = LibC.malloc length
        pointer.write_int value

      elsif string_option?(name)
        length ||= value.size

        # note: not checking errno for failed memory allocations :(
        pointer = LibC.malloc length
        pointer.write_string value
      end

      rc = LibZMQ.zmq_setsockopt @socket, name, pointer, length
      LibC.free(pointer) unless pointer.nil? || pointer.null?
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
    #  rc = socket.recv(message)
    #  if ZMQ::Util.resultcode_ok?(rc)
    #    message_parts << message
    #    while more_parts?
    #      message = Message.new
    #      rc = socket.recv(message)
    #      message_parts.push(message) if resulcode_ok?(rc)
    #    end
    #  end
    #
    def more_parts?
      array = []
      rc = getsockopt ZMQ::RCVMORE, array
      
      Util.resultcode_ok?(rc) ? array.at(0) : false
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
    #  socket.connect("tcp://127.0.0.1:5555")
    #
    def connect address
      rc = LibZMQ.zmq_connect @socket, address
    end

    # Closes the socket. Any unprocessed messages in queue are sent or dropped
    # depending upon the value of the socket option ZMQ::LINGER.
    #
    # Returns 0 upon success *or* when the socket has already been closed.
    # Returns -1 when the operation fails. Check ZMQ.errno for the error code.
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


    private

    def __getsockopt__ name, array
      value, length = sockopt_buffers name

      rc = LibZMQ.zmq_getsockopt @socket, name, value, length

      if Util.resultcode_ok?(rc)
        result = if int_option?(name)
          value.read_int
        elsif long_long_option?(name)
          value.read_long_long
        elsif string_option?(name)
          value.read_string(length.read_int)
        end

        array << result
      end

      rc
    end

    # Calls to ZMQ.getsockopt require us to pass in some pointers. We can cache and save those buffers
    # for subsequent calls. This is a big perf win for calling RCVMORE which happens quite often.
    # Cannot save the buffer for the IDENTITY.
    def sockopt_buffers name
      if long_long_option?(name)
        # int64_t or uint64_t
        unless @sockopt_cache[:int64]
          length = FFI::MemoryPointer.new :size_t
          length.write_int 8
          @sockopt_cache[:int64] = [FFI::MemoryPointer.new(:int64), length]
        end
        
        @sockopt_cache[:int64]

      elsif int_option?(name)
        # int, 0mq assumes int is 4-bytes
        unless @sockopt_cache[:int32]
          length = FFI::MemoryPointer.new :size_t
          length.write_int 4
          @sockopt_cache[:int32] = [FFI::MemoryPointer.new(:int32), length]
        end
        
        @sockopt_cache[:int32]

      elsif string_option?(name)
        length = FFI::MemoryPointer.new :size_t
        # could be a string of up to 255 bytes
        length.write_int 255
        [FFI::MemoryPointer.new(255), length]
        
      else
        # uh oh, someone passed in an unknown option; use a slop buffer
        unless @sockopt_cache[:unknown]
          length = FFI::MemoryPointer.new :size_t
          length.write_int 4
          @sockopt_cache[:unknown] = [FFI::MemoryPointer.new(:int32), length]
        end
        
        @sockopt_cache[:unknown]
      end
    end

    def supported_option? name
      int_option?(name) || long_long_option?(name) || string_option?(name)
    end

    def int_option? name
      EVENTS        == name ||
      LINGER        == name ||
      RECONNECT_IVL == name ||
      FD            == name ||
      TYPE          == name ||
      BACKLOG       == name
    end

    def string_option? name
      SUBSCRIBE   == name ||
      UNSUBSCRIBE == name
    end

    def long_long_option? name
      RCVMORE  == name ||
      AFFINITY == name
    end

    def unsupported_setsock_option? name
      RCVMORE == name
    end

    def unsupported_getsock_option? name
      UNSUBSCRIBE == name ||
      SUBSCRIBE   == name
    end

    def release_cache
      @sockopt_cache.clear
    end
  end # module CommonSocketBehavior


  module IdentitySupport

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


    private

    def string_option? name
      super ||
      IDENTITY == name
    end
  end # module IdentitySupport


  if LibZMQ.version2?

    class Socket
      # Inclusion order is *important* since later modules may have a call
      # to #super. We want those calls to go up the chain in a particular
      # order
      include CommonSocketBehavior
      include IdentitySupport

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
      #  ZMQ::MCAST_LOOP - true or false
      #  ZMQ::SNDBUF - integer
      #  ZMQ::RCVBUF - integer
      #  ZMQ::FD     - fd in an integer
      #  ZMQ::EVENTS - bitmap integer
      #  ZMQ::LINGER - integer measured in milliseconds
      #  ZMQ::RECONNECT_IVL - integer measured in milliseconds
      #  ZMQ::BACKLOG - integer
      #  ZMQ::RECOVER_IVL_MSEC - integer measured in milliseconds
      #
      # Returns 0 when the operation completed successfully.
      # Returns -1 when this operation failed.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      #  # retrieve high water mark
      #  array = []
      #  rc = socket.getsockopt(ZMQ::HWM, array)
      #  hwm = array.first if ZMQ::Util.resultcode_ok?(rc)
      #
      def getsockopt name, array
        rc = __getsockopt__ name, array
        
        if Util.resultcode_ok?(rc) && (RCVMORE == name || MCAST_LOOP == name)
          # convert to boolean
          array[0] = 1 == array[0]
        end
          
        rc
      end

      # Queues the message for transmission. Message is assumed to conform to the
      # same public API as #Message.
      #
      # +flags+ may take two values:
      # * 0 (default) - blocking operation
      # * ZMQ::NOBLOCK - non-blocking operation
      # * ZMQ::SNDMORE - this message is part of a multi-part message
      #
      # Returns 0 when the message was successfully enqueued.
      # Returns -1 under two conditions.
      # 1. The message could not be enqueued
      # 2. When +flags+ is set with ZMQ::NOBLOCK and the socket returned EAGAIN.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      # The application code is responsible for handling the +message+ object
      # lifecycle when #send returns. Regardless of the return code, the user
      # is responsible for calling message.close to free the memory in use.
      #
      def send message, flags = 0
        LibZMQ.zmq_send @socket, message.address, flags
      end

      # Helper method to make a new #Message instance out of the +message_string+ passed
      # in for transmission.
      #
      # +flags+ may be ZMQ::NOBLOCK.
      #
      # Returns 0 when the message was successfully enqueued.
      # Returns -1 under two conditions.
      # 1. The message could not be enqueued
      # 2. When +flags+ is set with ZMQ::NOBLOCK and the socket returned EAGAIN.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      def send_string message_string, flags = 0
        message = Message.new message_string
        send_and_close message, flags
      end

      # Send a sequence of strings as a multipart message out of the +parts+
      # passed in for transmission. Every element of +parts+ should be
      # a String.
      #
      # +flags+ may be ZMQ::NOBLOCK.
      #
      # Returns 0 when the message was successfully enqueued.
      # Returns -1 under two conditions.
      # 1. The message could not be enqueued
      # 2. When +flags+ is set with ZMQ::NOBLOCK and the socket returned EAGAIN.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      def send_strings parts, flags = 0
        return -1 if !parts || parts.empty?

        parts[0..-2].each do |part|
          rc = send_string part, flags | ZMQ::SNDMORE
          return rc unless Util.resultcode_ok?(rc)
        end

        send_string parts[-1], flags
      end

      # Send a sequence of messages as a multipart message out of the +parts+
      # passed in for transmission. Every element of +parts+ should be
      # a Message (or subclass).
      #
      # +flags+ may be ZMQ::NOBLOCK.
      #
      # Returns 0 when the message was successfully enqueued.
      # Returns -1 under two conditions.
      # 1. The message could not be enqueued
      # 2. When +flags+ is set with ZMQ::NOBLOCK and the socket returned EAGAIN.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      def send_messages parts, flags = 0
        return -1 if !parts || parts.empty?

        parts[0..-2].each do |part|
          rc = send part, flags | ZMQ::SNDMORE
          return rc unless Util.resultcode_ok?(rc)
        end

        send parts[-1], flags
      end

      # Sends a message. This will automatically close the +message+ for both successful
      # and failed sends.
      #
      # Returns 0 when the message was successfully enqueued.
      # Returns -1 under two conditions.
      # 1. The message could not be enqueued
      # 2. When +flags+ is set with ZMQ::NOBLOCK and the socket returned EAGAIN.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      def send_and_close message, flags = 0
        rc = send message, flags
        message.close
        rc
      end

      # Dequeues a message from the underlying queue. By default, this is a blocking operation.
      #
      # +flags+ may take two values:
      #  0 (default) - blocking operation
      #  ZMQ::NOBLOCK - non-blocking operation
      #
      # Returns 0 when the message was successfully dequeued.
      # Returns -1 under two conditions.
      # 1. The message could not be dequeued
      # 2. When +flags+ is set with ZMQ::NOBLOCK and the socket returned EAGAIN.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      # The application code is responsible for handling the +message+ object lifecycle
      # when #recv returns an error code.
      #
      def recv message, flags = 0
        LibZMQ.zmq_recv @socket, message.address, flags
      end

      # Converts the received message to a string and replaces the +string+ arg
      # contents.
      #
      # +string+ should be an empty string, .e.g. ''
      # +flags+ may be ZMQ::NOBLOCK.
      #
      # Returns 0 when the message was successfully dequeued.
      # Returns -1 under two conditions.
      # 1. The message could not be dequeued
      # 2. When +flags+ is set with ZMQ::NOBLOCK and the socket returned EAGAIN.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      def recv_string string, flags = 0
        message = @receiver_klass.new
        rc = recv message, flags
        string.replace(message.copy_out_string) if Util.resultcode_ok?(rc)
        message.close
        rc
      end

      # Receive a multipart message as a list of strings.
      #
      # +list+ should be an object that responds to #append or #<< so received
      # strings can be appended to it
      # +flag+ may be ZMQ::NOBLOCK. Any other flag will be removed
      #
      # Returns 0 when all messages were successfully dequeued.
      # Returns -1 under two conditions.
      # 1. A message could not be dequeued
      # 2. When +flags+ is set with ZMQ::NOBLOCK and the socket returned EAGAIN.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause. Also, the +list+ will not be modified when there was an error.
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
      # +list+ should be an object that responds to #append or #<< so received
      # messages can be appended to it
      # +flag+ may be ZMQ::NOBLOCK. Any other flag will be
      # removed.
      #
      # Returns 0 when all messages were successfully dequeued.
      # Returns -1 under two conditions.
      # 1. A message could not be dequeued
      # 2. When +flags+ is set with ZMQ::NOBLOCK and the socket returned EAGAIN.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause. Also, the +list+ will not be modified when there was an error.
      #
      def recvmsgs list, flag = 0
        flag = NOBLOCK if noblock?(flag)

        parts = []
        message = @receiver_klass.new
        rc = recv message, flag
        parts << message

        while more_parts? && Util.resultcode_ok?(rc)
          message = @receiver_klass.new
          rc = recv message, flag
          parts << message
        end

        # only append the received parts if there were no errors
        # FIXME:
        # need to detect EAGAIN if flag is set; EAGAIN means we have read all that we
        # can and should return whatever was already read; need a spec!
        if Util.resultcode_ok?(rc)
          parts.each { |part| list << part }
        end

        rc
      end


      private

      def noblock? flags
        (NOBLOCK & flags) == NOBLOCK
      end

      def int_option? name
        super ||
        RECONNECT_IVL_MAX == name
      end

      def long_long_option? name
        super ||
        HWM               == name ||
        SWAP              == name ||
        RATE              == name ||
        RECOVERY_IVL      == name ||
        RECOVERY_IVL_MSEC == name ||
        MCAST_LOOP        == name ||
        SNDBUF            == name ||
        RCVBUF            == name
      end

      # these finalizer-related methods cannot live in the CommonSocketBehavior
      # module; they *must* be in the class definition directly

      def define_finalizer
        ObjectSpace.define_finalizer(self, self.class.close(@socket))
      end

      def remove_finalizer
        ObjectSpace.undefine_finalizer self
      end

      def self.close socket
        Proc.new { LibZMQ.zmq_close socket }
      end
    end # class Socket for version2

  end # LibZMQ.version2?


  if LibZMQ.version3?
    class Socket
      include CommonSocketBehavior
      include IdentitySupport

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
      #
      # Returns 0 when the operation completed successfully.
      # Returns -1 when this operation failed.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
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

      # The last message part received is tested to see if it is a label.
      #
      # Equivalent to calling Socket#getsockopt with ZMQ::RCVLABEL.
      #
      # Warning: if the call to #getsockopt fails, this method will return
      # false and swallow the error.
      #
      #  labels = []
      #  message_parts = []
      #  message = Message.new
      #  rc = socket.recv(message)
      #  if ZMQ::Util.resultcode_ok?(rc)
      #    label? ? labels.push(message) : message_parts.push(message)
      #    while more_parts?
      #      message = Message.new
      #      if ZMQ::Util.resulcode_ok?(socket.recv(message))
      #        label? ? labels.push(message) : message_parts.push(message)
      #      end
      #    end
      #  end
      #
      def label?
        array = []
        rc = getsockopt ZMQ::RCVLABEL, array
        
        Util.resultcode_ok?(rc) ? array.at(0) : false
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
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      def sendmsg message, flags = 0
        LibZMQ.zmq_sendmsg @socket, message.address, flags
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
      # With a -1 return code, the user must check ZMQ.errno to determine the
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
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      def send_strings parts, flags = 0
        return -1 if !parts || parts.empty?
        flags = DONTWAIT if dontwait?(flags)
        
        parts[0..-2].each do |part|
          rc = send_string part, (flags | ZMQ::SNDMORE)
          return rc unless Util.resultcode_ok?(rc)
        end

        send_string parts[-1], flags
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
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      def send_messages parts, flags = 0
        return -1 if !parts || parts.empty?
        flags = DONTWAIT if dontwait?(flags)
        
        parts[0..-2].each do |part|
          rc = sendmsg part, (flags | ZMQ::SNDMORE)
          return rc unless Util.resultcode_ok?(rc)
        end

        sendmsg parts[-1], flags
      end

      # Sends a message. This will automatically close the +message+ for both successful
      # and failed sends.
      #
      # Returns 0 when the message was successfully enqueued.
      # Returns -1 under two conditions.
      # 1. The message could not be enqueued
      # 2. When +flags+ is set with ZMQ::DONTWAIT and the socket returned EAGAIN.
      #
      # With a -1 return code, the user must check ZMQ.errno to determine the
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
      # With a -1 return code, the user must check ZMQ.errno to determine the
      # cause.
      #
      # The application code is responsible for handling the +message+ object lifecycle
      # when #recv returns an error code.
      #
      def recvmsg message, flags = 0
        LibZMQ.zmq_recvmsg @socket, message.address, flags
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
      # With a -1 return code, the user must check ZMQ.errno to determine the
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
      # Raises the same exceptions as Socket#recv.
      #
      def recvmsgs list, flag = 0
        flag = DONTWAIT if dontwait?(flag)

        parts = []
        message = @receiver_klass.new
        rc = recvmsg message, flag
        parts << message

        while Util.resultcode_ok?(rc) && more_parts?
          message = @receiver_klass.new
          rc = recvmsg message, flag
          parts << message
        end

        # only append the received parts if there were no errors
        if Util.resultcode_ok?(rc)
          parts.each { |part| list << part }
        end

        rc
      end


      private

      def dontwait? flags
        (DONTWAIT & flags) == DONTWAIT
      end
      alias :noblock? :dontwait?

      def int_option? name
        super ||
        RCVLABEL          == name ||
        RECONNECT_IVL_MAX == name ||
        RCVHWM            == name ||
        SNDHWM            == name ||
        RATE              == name ||
        RECOVERY_IVL      == name ||
        SNDBUF            == name ||
        RCVBUF            == name
      end

      # these finalizer-related methods cannot live in the CommonSocketBehavior
      # module; they *must* be in the class definition directly

      def define_finalizer
        ObjectSpace.define_finalizer(self, self.class.close(@socket))
      end

      def remove_finalizer
        ObjectSpace.undefine_finalizer self
      end

      def self.close socket
        Proc.new { LibZMQ.zmq_close socket }
      end
    end # Socket for version3
  end # LibZMQ.version3?

end # module ZMQ

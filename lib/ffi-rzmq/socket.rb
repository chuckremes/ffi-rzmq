
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
    # Can raise two kinds of exceptions depending on the error.
    # ContextError:: Raised when a socket operation is attempted on a terminated
    # #Context. See #ContextError.
    # SocketError:: See all of the possibilities in the docs for #SocketError.
    #
    def initialize context_ptr, type, opts = {:receiver_class => ZMQ::Message}
      # users may override the classes used for receiving; class must conform to the
      # same public API as ZMQ::Message
      @receiver_klass = opts[:receiver_class]

      unless context_ptr.null?
        @socket = LibZMQ.zmq_socket context_ptr, type
        if @socket
          error_check 'zmq_socket', @socket.null? ? 1 : 0
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
    # Can raise two kinds of exceptions depending on the error.
    # ContextError:: Raised when a socket operation is attempted on a terminated
    # #Context. See #ContextError.
    # SocketError:: See all of the possibilities in the docs for #SocketError.
    #
    def setsockopt name, value, length = nil
      begin
        if unsupported_setsock_option?(name) || !supported_option?(name)
          error_check 'zmq_setsockopt', EINVAL

        elsif long_long_option?(name)
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

        else
          # we didn't understand the passed option argument
          # will force a raise due to EINVAL being non-zero
          error_check 'zmq_setsockopt', EINVAL
        end

        result_code = LibZMQ.zmq_setsockopt @socket, name, pointer, length
        error_check 'zmq_setsockopt', result_code
      ensure
        LibC.free(pointer) unless pointer.nil? || pointer.null?
      end
    end

    # Get the options set on this socket. Returns a value dependent upon
    # the +name+ requested.
    #
    # Valid +option_name+ values and their return types:
    #  ZMQ::RCVMORE - 0 for false, 1 for true
    #  ZMQ::HWM - integer
    #  ZMQ::SWAP - integer
    #  ZMQ::AFFINITY - bitmap in an integer
    #  ZMQ::IDENTITY - string
    #  ZMQ::RATE - integer
    #  ZMQ::RECOVERY_IVL - integer
    #  ZMQ::MCAST_LOOP - 0 for false, 1 for true
    #  ZMQ::SNDBUF - integer
    #  ZMQ::RCVBUF - integer
    #  ZMQ::FD     - fd in an integer
    #  ZMQ::EVENTS - bitmap integer
    #  ZMQ::LINGER - integer measured in milliseconds
    #  ZMQ::RECONNECT_IVL - integer measured in milliseconds
    #  ZMQ::BACKLOG - integer
    #  ZMQ::RECOVER_IVL_MSEC - integer measured in milliseconds
    #
    # Can raise two kinds of exceptions depending on the error.
    # ContextError:: Raised when a socket operation is attempted on a terminated
    # #Context. See #ContextError.
    # SocketError:: See all of the possibilities in the docs for #SocketError.
    #
    def getsockopt name
      if unsupported_getsock_option?(name) || !supported_option?(name)
        # we didn't understand the passed option argument
        # will force a raise
        error_check 'zmq_getsockopt', -1
      end

      value, length = sockopt_buffers name

      result_code = LibZMQ.zmq_getsockopt @socket, name, value, length
      error_check 'zmq_getsockopt', result_code

      ret = if int_option?(name)
        value.read_int
      elsif long_long_option?(name)
        value.read_long_long
      elsif string_option?(name)
        value.read_string(length.read_long_long)
      end

      ret
    end

    # Convenience method for checking on additional message parts.
    #
    # Equivalent to Socket#getsockopt ZMQ::RCVMORE
    #
    def more_parts?
      0 != getsockopt(ZMQ::RCVMORE)
    end

    # Can raise two kinds of exceptions depending on the error.
    # ContextError:: Raised when a socket operation is attempted on a terminated
    # #Context. See #ContextError.
    # SocketError:: See all of the possibilities in the docs for #SocketError.
    #
    def bind address
      result_code = LibZMQ.zmq_bind @socket, address
      error_check 'zmq_bind', result_code
    end

    # Can raise two kinds of exceptions depending on the error.
    # ContextError:: Raised when a socket operation is attempted on a terminated
    # #Context. See #ContextError.
    # SocketError:: See all of the possibilities in the docs for #SocketError.
    #
    def connect address
      result_code = LibZMQ.zmq_connect @socket, address
      error_check 'zmq_connect', result_code
    end

    # Closes the socket. Any unprocessed messages in queue are sent or dropped
    # depending upon the value of the socket option ZMQ::LINGER.
    #
    def close
      if @socket
        remove_finalizer
        result_code = LibZMQ.zmq_close @socket
        error_check 'zmq_close', result_code
        @socket = nil
        release_cache
      end
    end


    private

    # Calls to ZMQ.getsockopt require us to pass in some pointers. We can cache and save those buffers
    # for subsequent calls. This is a big perf win for calling RCVMORE which happens quite often.
    # Cannot save the buffer for the IDENTITY.
    def sockopt_buffers name
      if long_long_option?(name)
        # int64_t or uint64_t
        unless @sockopt_cache[:int64]
          length = FFI::MemoryPointer.new :int64
          length.write_long_long 8
          @sockopt_cache[:int64] = [FFI::MemoryPointer.new(:int64), length]
        end
        @sockopt_cache[:int64]

      elsif int_option?(name)
        # int, 0mq assumes int is 4-bytes
        unless @sockopt_cache[:int32]
          length = FFI::MemoryPointer.new :int32
          length.write_int 4
          @sockopt_cache[:int32] = [FFI::MemoryPointer.new(:int32), length]
        end
        @sockopt_cache[:int32]

      elsif string_option?(name)
        length = FFI::MemoryPointer.new :int64
        # could be a string of up to 255 bytes
        length.write_long_long 255
        [FFI::MemoryPointer.new(255), length]
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
      getsockopt IDENTITY
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

      # Queues the message for transmission. Message is assumed to conform to the
      # same public API as #Message.
      #
      # +flags+ may take two values:
      # * 0 (default) - blocking operation
      # * ZMQ::NOBLOCK - non-blocking operation
      # * ZMQ::SNDMORE - this message is part of a multi-part message
      #
      # Returns true when the message was successfully enqueued.
      # Returns false under two conditions.
      # 1. The message could not be enqueued
      # 2. When +flags+ is set with ZMQ::NOBLOCK and the socket returned EAGAIN.
      #
      # The application code is responsible for handling the +message+ object
      # lifecycle when #send returns.
      #
      # Can raise two kinds of exceptions depending on the error.
      # ContextError:: Raised when a socket operation is attempted on a terminated
      # #Context. See #ContextError.
      # SocketError:: See all of the possibilities in the docs for #SocketError.
      #
      def send message, flags = 0
        begin
          result_code = LibZMQ.zmq_send @socket, message.address, flags

          # when the flag isn't set, do a normal error check
          # when set, check to see if the message was successfully queued
          queued = noblock?(flags) ? error_check_nonblock(result_code) : error_check('zmq_send', result_code)
        end

        # true if sent, false if failed/EAGAIN
        queued
      end

      # Helper method to make a new #Message instance out of the +message_string+ passed
      # in for transmission.
      #
      # +flags+ may be ZMQ::NOBLOCK.
      #
      # Can raise two kinds of exceptions depending on the error.
      # ContextError:: Raised when a socket operation is attempted on a terminated
      # #Context. See #ContextError.
      # SocketError:: See all of the possibilities in the docs for #SocketError.
      #
      def send_string message_string, flags = 0
        message = Message.new message_string
        result_code = send_and_close message, flags

        result_code
      end

      # Send a sequence of strings as a multipart message out of the +parts+
      # passed in for transmission. Every element of +parts+ should be
      # a String.
      #
      # +flags+ may be ZMQ::NOBLOCK.
      #
      # Raises the same exceptions as Socket#send.
      #
      def send_strings parts, flags = 0
        return false if !parts || parts.empty?

        parts[0...-1].each do |part|
          return false unless send_string part, flags | ZMQ::SNDMORE
        end

        send_string parts[-1], flags
      end

      # Sends a message. This will automatically close the +message+ for both successful
      # and failed sends.
      #
      # Raises the same exceptions as Socket#send
      #
      def send_and_close message, flags = 0
        begin
          result_code = send message, flags
        ensure
          message.close
        end
        result_code
      end

      # Dequeues a message from the underlying queue. By default, this is a blocking operation.
      #
      # +flags+ may take two values:
      #  0 (default) - blocking operation
      #  ZMQ::NOBLOCK - non-blocking operation
      #
      # Returns a true when it successfully dequeues one from the queue. Also, the +message+
      # object is populated by the library with a data buffer containing the received
      # data.
      #
      # Returns nil when a message could not be dequeued *and* +flags+ is set
      # with ZMQ::NOBLOCK. The +message+ object is not modified in this situation.
      #
      # The application code is *not* responsible for handling the +message+ object lifecycle
      # when #recv raises an exception. The #recv method takes ownership of the
      # +message+ and its associated buffers. A failed call will
      # release the data buffers assigned to the +message+.
      #
      # Can raise two kinds of exceptions depending on the error.
      # ContextError:: Raised when a socket operation is attempted on a terminated
      # #Context. See #ContextError.
      # SocketError:: See all of the possibilities in the docs for #SocketError.
      #
      def recv message, flags = 0
        begin
          dequeued = _recv message, flags
        rescue ZeroMQError
          message.close
          raise
        end

        dequeued ? true : nil
      end

      # Helper method to make a new #Message instance and convert its payload
      # to a string.
      #
      # +flags+ may be ZMQ::NOBLOCK.
      #
      # Can raise two kinds of exceptions depending on the error.
      # ContextError:: Raised when a socket operation is attempted on a terminated
      # #Context. See #ContextError.
      # SocketError:: See all of the possibilities in the docs for #SocketError.
      #
      def recv_string flags = 0
        message = @receiver_klass.new

        begin
          dequeued = _recv message, flags

          if dequeued
            message.copy_out_string
          else
            nil
          end
        ensure
          message.close
        end
      end

      # Receive a multipart message as a list of strings.
      #
      # +flag+ may be ZMQ::NOBLOCK. Any other flag will be
      # removed.
      #
      # Raises the same exceptions as Socket#recv.
      #
      def recv_strings flag = 0
        recvmsgs.map { |message| message.copy_out_string }
      end

      # Receive a multipart message as an array of objects
      # (by default these are instances of Message).
      #
      # +flag+ may be ZMQ::NOBLOCK. Any other flag will be
      # removed.
      #
      # Raises the same exceptions as Socket#recv.
      #
      def recvmsgs flag = 0
        flag = NOBLOCK if noblock?(flag)

        parts = []
        message = @receiver_klass.new
        rc = recv message, flag
        parts << message if rc
        
        while more_parts?
          message = @receiver_klass.new
          rc = recv message, flag
          parts << message if rc
        end
        
        parts
      end


      private

      def noblock? flags
        (NOBLOCK & flags) == NOBLOCK
      end

      def _recv message, flags = 0
        result_code = LibZMQ.zmq_recv @socket, message.address, flags

        if noblock?(flags)
          error_check_nonblock result_code
        else
          error_check 'zmq_send', result_code
        end
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

  end # if LibZMQ.version2?

end # module ZMQ


module ZMQ

  ZMQ_SOCKET_STR = 'zmq_socket'.freeze unless defined? ZMQ_SOCKET_STR
  ZMQ_SETSOCKOPT_STR = 'zmq_setsockopt'.freeze
  ZMQ_GETSOCKOPT_STR = 'zmq_getsockopt'.freeze
  ZMQ_BIND_STR = 'zmq_bind'.freeze
  ZMQ_CONNECT_STR = 'zmq_connect'.freeze
  ZMQ_CLOSE_STR = 'zmq_close'.freeze
  ZMQ_SEND_STR = 'zmq_send'.freeze
  ZMQ_RECV_STR = 'zmq_recv'.freeze

  class Socket
    include ZMQ::Util

    attr_reader :socket, :name

    # Allocates a socket of type +type+ for sending and receiving data.
    #
    # +type+ can be one of ZMQ::REQ, ZMQ::REP, ZMQ::PUB,
    # ZMQ::SUB, ZMQ::PAIR, ZMQ::PULL, ZMQ::PUSH,
    # ZMQ::XREQ or ZMQ::XREP.
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
        error_check ZMQ_SOCKET_STR, @socket.null? ? 1 : 0
        @name = SocketTypeNameMap[type]
      else
        raise ContextError.new ZMQ_SOCKET_STR, 0, ETERM, "Context pointer was null"
      end

      #define_finalizer
    end

    # Set the queue options on this socket.
    #
    # Valid +option_name+ values that take a numeric +option_value+ are:
    #  ZMQ::HWM
    #  ZMQ::SWAP
    #  ZMQ::AFFINITY
    #  ZMQ::RATE
    #  ZMQ::RECOVERY_IVL
    #  ZMQ::MCAST_LOOP
    #
    # Valid +option_name+ values that take a string +option_value+ are:
    #  ZMQ::IDENTITY
    #  ZMQ::SUBSCRIBE
    #  ZMQ::UNSUBSCRIBE
    #
    # Can raise two kinds of exceptions depending on the error.
    # ContextError:: Raised when a socket operation is attempted on a terminated
    # #Context. See #ContextError.
    # SocketError:: See all of the possibilities in the docs for #SocketError.
    #
    def setsockopt option_name, option_value, option_len = nil
      option_value = sanitize_value option_name, option_value
      option_len ||= option_value.size
      
      begin
        case option_name
        when HWM, SWAP, AFFINITY, RATE, RECOVERY_IVL, MCAST_LOOP, SNDBUF, RCVBUF
          option_value_ptr = LibC.malloc option_len
          option_value_ptr.write_long option_value

        when IDENTITY, SUBSCRIBE, UNSUBSCRIBE
          # note: not checking errno for failed memory allocations :(
          option_value_ptr = LibC.malloc option_len
          option_value_ptr.write_string option_value

        else
          # we didn't understand the passed option argument
          # will force a raise due to EINVAL being non-zero
          error_check ZMQ_SETSOCKOPT_STR, EINVAL
        end

        result_code = LibZMQ.zmq_setsockopt @socket, option_name, option_value_ptr, option_len
        error_check ZMQ_SETSOCKOPT_STR, result_code
      ensure
        LibC.free option_value_ptr unless option_value_ptr.nil? || option_value_ptr.null?
      end
    end

    # Get the options set on this socket. Returns a value dependent upon
    # the +option_name+ requested.
    #
    # Valid +option_name+ values and their return types:
    #  ZMQ::RCVMORE - boolean
    #  ZMQ::HWM - integer
    #  ZMQ::SWAP - integer
    #  ZMQ::AFFINITY - bitmap in an integer
    #  ZMQ::IDENTITY - string
    #  ZMQ::RATE - integer
    #  ZMQ::RECOVERY_IVL - integer
    #  ZMQ::MCAST_LOOP - boolean
    #  ZMQ::SNDBUF - integer
    #  ZMQ::RCVBUF - integer
    #
    # Can raise two kinds of exceptions depending on the error.
    # ContextError:: Raised when a socket operation is attempted on a terminated
    # #Context. See #ContextError.
    # SocketError:: See all of the possibilities in the docs for #SocketError.
    #
    def getsockopt option_name
      begin
        option_value = FFI::MemoryPointer.new :pointer
        option_length = FFI::MemoryPointer.new :size_t

        unless [RCVMORE, HWM, SWAP, AFFINITY, RATE, RECOVERY_IVL, MCAST_LOOP,
        IDENTITY, SNDBUF, RCVBUF].include? option_name
        # we didn't understand the passed option argument
        # will force a raise
        error_check ZMQ_SETSOCKOPT_STR, -1
      end

      option_value, option_length = alloc_temp_sockopt_buffers option_name

      result_code = LibZMQ.zmq_getsockopt @socket, option_name, option_value, option_length
      error_check ZMQ_GETSOCKOPT_STR, result_code
      ret = 0

      case option_name
      when RCVMORE, MCAST_LOOP
        # boolean return
        ret = option_value.read_long_long != 0
      when HWM, SWAP, AFFINITY, RATE, RECOVERY_IVL, SNDBUF, RCVBUF
        ret = option_value.read_long_long
      when IDENTITY
        ret = option_value.read_string(option_length.read_long_long)
      end

      ret
    end
  end

  # Convenience method for checking on additional message parts.
  #
  # Equivalent to Socket#getsockopt ZMQ::RCVMORE
  #
  def more_parts?
    getsockopt ZMQ::RCVMORE
  end

  # Convenience method for getting the value of the socket IDENTITY.
  #
  def identity
    getsockopt ZMQ::IDENTITY
  end

  # Convenience method for setting the value of the socket IDENTITY.
  #
  def identity= value
    setsockopt ZMQ::IDENTITY, value.to_s
  end

  # Can raise two kinds of exceptions depending on the error.
  # ContextError:: Raised when a socket operation is attempted on a terminated
  # #Context. See #ContextError.
  # SocketError:: See all of the possibilities in the docs for #SocketError.
  #
  def bind address
    result_code = LibZMQ.zmq_bind @socket, address
    error_check ZMQ_BIND_STR, result_code
  end

  # Can raise two kinds of exceptions depending on the error.
  # ContextError:: Raised when a socket operation is attempted on a terminated
  # #Context. See #ContextError.
  # SocketError:: See all of the possibilities in the docs for #SocketError.
  #
  def connect address
    result_code = LibZMQ.zmq_connect @socket, address
    error_check ZMQ_CONNECT_STR, result_code
  end

  # Closes the socket. Any unprocessed messages in queue are dropped.
  #
  def close
    remove_finalizer
    result_code = LibZMQ.zmq_close @socket
    error_check ZMQ_CLOSE_STR, result_code
  end

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
  # The application code is *not* responsible for handling the +message+ object
  # lifecycle when #send returns successfully or it raises an exception. The
  # #send method takes ownership of the +message+ and its associated buffers.
  # Both successful and failed calls will release the +message+ data buffer.
  #
  # Again, once a +message+ object has been passed to this method,
  # do not try to access its #data buffer anymore. The 0mq library now owns it.
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
      queued = flags != NOBLOCK ? error_check(ZMQ_SEND_STR, result_code) : error_check_nonblock(result_code)
    ensure
      message.close
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
    message = Message.new
    message.copy_in_string message_string
    result = send message, flags
    result
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

  private

  def _recv message, flags = 0
    result_code = LibZMQ.zmq_recv @socket, message.address, flags

    flags != NOBLOCK ? error_check(ZMQ_RECV_STR, result_code) : error_check_nonblock(result_code)
  end

  def alloc_temp_sockopt_buffers option_name
    length = FFI::MemoryPointer.new :int64

    case option_name
    when RCVMORE, MCAST_LOOP, HWM, SWAP, AFFINITY, RATE, RECOVERY_IVL, SNDBUF, RCVBUF
      # int64_t
      length.write_long_long 8
      [FFI::MemoryPointer.new(:int64), length]
    when IDENTITY
      # could be a string of up to 255 bytes
      length.write_long_long 255
      [FFI::MemoryPointer.new(255), length]
    end
  end
  
  def sanitize_value option_name, option_value
    case option_name
    when HWM, AFFINITY, SNDBUF, RCVBUF
      option_value.abs
    when MCAST_LOOP
      option_value ? 1 : 0
    else
      option_value
    end
  end

  def define_finalizer
    ObjectSpace.define_finalizer(self, self.class.close(@socket))
  end

  def remove_finalizer
    ObjectSpace.undefine_finalizer self
  end

  def self.close socket
    Proc.new { LibZMQ.zmq_close socket }
  end
end # class Socket

end # module ZMQ

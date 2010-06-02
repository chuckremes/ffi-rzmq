
module ZMQ

  ZMQ_SOCKET_STR = 'zmq_socket'.freeze unless defined? ZMQ_SOCKET_STR
  ZMQ_SETSOCKOPT_STR = 'zmq_setsockopt'.freeze
  ZMQ_BIND_STR = 'zmq_bind'.freeze
  ZMQ_CONNECT_STR = 'zmq_connect'.freeze
  ZMQ_CLOSE_STR = 'zmq_close'.freeze
  ZMQ_SEND_STR = 'zmq_send'.freeze
  ZMQ_RECV_STR = 'zmq_recv'.freeze

  class Socket
    include ZMQ::Util

    attr_reader :socket

    # By default, this class uses ZMQ::Message for regular Ruby
    # memory management.
    #
    # +type+ can be one of ZMQ::REQ, ZMQ::REP, ZMQ::PUB,
    # ZMQ::SUB, ZMQ::PAIR, ZMQ::UPSTREAM, ZMQ::DOWNSTREAM,
    # ZMQ::XREQ or ZMQ::XREP.
    #
    # Can raise two kinds of exceptions depending on the error.
    # ContextError:: Raised when a socket operation is attempted on a terminated
    # #Context. See #ContextError.
    # SocketError:: See all of the possibilities in the docs for #SocketError.
    #
    def initialize context_ptr, type
      # maybe at some point we'll want to allow users to override this with their
      # own classes? Or is this a YAGNI mistake?
      @sender_klass = ZMQ::Message
      @receiver_klass = ZMQ::Message

      @socket = LibZMQ.zmq_socket context_ptr, type
      error_check ZMQ_SOCKET_STR, @socket.nil? ? 1 : 0

      define_finalizer
    end

    # Set the queue options on this socket.
    #
    # Valid +option_name+ values that take a numeric +option_value+ are:
    #  ZMQ::HWM
    #  ZMQ::LWM
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
      begin
        case option_name
        when HWM, LWM, SWAP, AFFINITY, RATE, RECOVERY_IVL, MCAST_LOOP
          option_value_ptr = LibC.malloc option_value.size
          option_value_ptr.write_long option_value

        when IDENTITY, SUBSCRIBE, UNSUBSCRIBE
          # note: not checking errno for failed memory allocations :(
          option_value_ptr = LibC.malloc option_value.size
          option_value_ptr.write_string option_value

        else
          # we didn't understand the passed option argument
          # will force a raise due to EINVAL being non-zero
          error_check ZMQ_SETSOCKOPT_STR, EINVAL
        end

        result_code = LibZMQ.zmq_setsockopt @socket, option_name, option_value_ptr, option_len || option_value.size
        error_check ZMQ_SETSOCKOPT_STR, result_code
      ensure
        LibC.free option_value_ptr unless option_value_ptr.null?
      end
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
      LibZMQ.zmq_close @socket
      remove_finalizer
    end

    # Queues the message for transmission. Message is assumed to be an instance or
    # subclass of #Message.
    #
    # +flags+ may take two values:
    # * 0 (default) - blocking operation
    # * ZMQ::NOBLOCK - non-blocking operation
    #
    # Returns true when the message was successfully enqueued.
    # Returns false when the message could not be enqueued *and* +flags+ is set
    # with ZMQ::NOBLOCK.
    #
    # The application code is *not* responsible for handling the +message+ object
    # lifecycle when #send return ZMQ::NOBLOCK or it raises an exception. The
    # #send method takes ownership of the +message+ and its associated buffers.
    # A failed call will release the +message+ data buffer.
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
        queued = flags.zero? ? error_check(ZMQ_SEND_STR, result_code) : error_check_nonblock(result_code)
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
      message = @sender_klass.new
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

      flags.zero? ? error_check(ZMQ_RECV_STR, result_code) : error_check_nonblock(result_code)
    end

    def define_finalizer
      #ObjectSpace.define_finalizer(self, self.class.close(@socket))
    end

    def remove_finalizer
      #ObjectSpace.undefine_finalizer self
    end

    def self.close socket
      Proc.new { LibZMQ.zmq_close socket }
    end
  end # class Socket

end # module ZMQ


module ZMQ

  ZMQ_SETSOCKOPT_STR = 'zmq_setsockopt'.freeze
  ZMQ_BIND_STR = 'zmq_bind'.freeze
  ZMQ_CONNECT_STR = 'zmq_connect'.freeze
  ZMQ_SEND_STR = 'zmq_send'.freeze
  ZMQ_RECV_STR = 'zmq_recv'.freeze

  class Socket
    include ZMQ::Util

    def initialize context_ptr, type
      @socket = LibZMQ.zmq_socket context_ptr, type
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
    # May raise a ZeroMQError when the operation fails or when passed an
    # invalid +option_name+.
    #
    def setsockopt option_name, option_value, size = nil
      begin
        case option_name
        when HWM, LWM, SWAP, AFFINITY, RATE, RECOVERY_IVL, MCAST_LOOP
          option_value_ptr = FFI::MemoryPointer.new :long
          option_value_ptr.write_long option_value

        when IDENTITY, SUBSCRIBE, UNSUBSCRIBE
          option_value_ptr = FFI::MemoryPointer.from_string option_value

        else
          # we didn't understand the passed option argument
          # will force a raise due to EINVAL being non-zero
          error_check ZMQ_SETSOCKOPT_STR, EINVAL
        end

        result_code = LibZMQ.zmq_setsockopt @socket, option_name, option_value_ptr, size || option_value.size
        error_check ZMQ_SETSOCKOPT_STR, result_code
      ensure
        option_value_ptr.free
      end
    end

    def bind address
      result_code = LibZMQ.zmq_bind @socket, address
      error_check ZMQ_BIND_STR, result_code
    end

    def connect address
      result_code = LibZMQ.zmq_connect @socket, address
      error_check ZMQ_CONNECT_STR, result_code
    end

    # Queues the message for transmission. Message is assumed to be an instance or
    # subclass of +Message+.
    #
    # +flags+ may take two values:
    #  0 (default) - blocking operation
    #  ZMQ::NOBLOCK - non-blocking operation
    #
    # Returns true when the message was successfully enqueued.
    # Returns false when the message could not be enqueued *and* +flags+ is set
    # with ZMQ::NOBLOCK
    #
    # May raise a ZeroMQError for other failure modes. The exception will
    # contain a string describing the problem.
    #
    def send message, flags = 0
      result_code = LibZMQ.zmq_send @socket, message.address, flags

      # when the flag isn't set, do a normal error check
      # when set, check to see if the message was successfully queued
      begin
        queued = flags.zero? ? error_check(ZMQ_SEND_STR, result_code) : error_check_nonblock(result_code)
      ensure
        message = nil
      end

      queued # true if sent, false if failed/EAGAIN
    end

    # Helper method to make a new +Message+ instance out of the +message_string+ passed
    # in for transmission.
    def send_string message_string, flags
      message = Message.new message_string
      send message, flags
    end

    # Dequeues a message from the underlying queue. By default, this is a blocking operation.
    #
    # +flags+ may take two values:
    #  0 (default) - blocking operation
    #  ZMQ::NOBLOCK - non-blocking operation
    #
    # Returns a message when it successfully dequeues one from the queue.
    # Returns nil when a message could not be dequeued *and* +flags+ is set
    # with ZMQ::NOBLOCK
    #
    # May raise a ZeroMQError for other failure modes. The exception will
    # contain a string describing the problem.
    #
    def recv flags = 0
      message = Message.new
      result_code = LibZMQ.zmq_recv @socket, message.address, flags

      begin
        dequeued = flags.zero? ? error_check(ZMQ_RECV_STR, result_code) : error_check_nonblock(result_code)
      rescue ZeroMQError
        dequeued = false
        raise
      ensure
        unless dequeued
          message = nil # may release buffers during next GC run
        end
      end

      message
    end
    
    def recv_string flags = 0
      message = recv flags
      
      if message
        message.data_as_string
      else
        nil
      end
    end

  end # class Socket

end # module ZMQ

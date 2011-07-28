
module ZMQ

  class ZeroMQError < StandardError
    attr_reader :source, :result_code, :error_code, :message

    def initialize source, result_code, error_code, message
      @source = source
      @result_code = result_code
      @error_code = error_code
      @message = "msg [#{message}], error code [#{error_code}], rc [#{result_code}]"
      super message
    end
  end # call ZeroMQError


  class ContextError < ZeroMQError
    # True when the exception was raised due to the library
    # returning EINVAL.
    #
    # Occurs when he number of app_threads requested is less
    # than one, or the number of io_threads requested is
    # negative.
    #
    def einval?() EINVAL == @error_code; end

    # True when the exception was raised due to the library
    # returning ETERM.
    #
    # The associated context was terminated.
    #
    def eterm?() ETERM == @error_code; end

  end # class ContextError


  class PollError < ZeroMQError
    # True when the exception was raised due to the library
    # returning EMTHREAD.
    #
    # At least one of the members of the items array refers
    # to a socket belonging to a different application
    # thread.
    #
    def efault?() EFAULT == @error_code; end

  end # class PollError


  class SocketError < ZeroMQError
    # True when the exception was raised due to the library
    # returning EMTHREAD.
    #
    # Occurs for #send and #recv operations.
    # * When calling #send, non-blocking mode was requested
    # and the message cannot be queued at the moment.
    # * When calling #recv, non-blocking mode was requested
    # and no messages are available at the moment.
    #
    def egain?() EAGAIN == @error_code; end

    # True when the exception was raised due to the library
    # returning ENOCOMPATPROTO.
    #
    # The requested transport protocol is not compatible
    # with the socket type.
    #
    def enocompatproto?() ENOCOMPATPROTO == @error_code; end

    # True when the exception was raised due to the library
    # returning EPROTONOSUPPORT.
    #
    # The requested transport protocol is not supported.
    #
    def eprotonosupport?() EPROTONOSUPPORT == @error_code; end

    # True when the exception was raised due to the library
    # returning EADDRINUSE.
    #
    # The given address is already in use.
    #
    def eaddrinuse?() EADDRINUSE == @error_code; end

    # True when the exception was raised due to the library
    # returning EADDRNOTAVAIL.
    #
    # A nonexistent interface was requested or the
    # requested address was not local.
    #
    def eaddrnotavail?() EADDRNOTAVAIL == @error_code; end

    # True when the exception was raised due to the library
    # returning EMTHREAD.
    #
    # Occurs under 2 conditions.
    # * When creating a new #Socket, the requested socket
    # type is invalid.
    #
    # * When setting socket options with #setsockopt, the
    # requested option +option_name+ is unknown, or the
    # requested +option_len+ or +option_value+ is invalid.
    #
    def einval?() EINVAL == @error_code; end

    # True when the exception was raised due to the library
    # returning EMTHREAD.
    #
    # The send or recv operation cannot be performed on this
    # socket at the moment due to the socket not being in
    # the appropriate state. This error may occur with socket
    # types that switch between several states, such as ZMQ::REP.
    #
    def efsm?() EFSM == @error_code; end

    # True when the exception was raised due to the library
    # returning ENOTSUP.
    #
    # The send or recv operation is not supported by this socket
    # type.
    #
    def enotsup?() super; end

    # True when the exception was raised due to the library
    # returning EMTHREAD.
    #
    # The number of application threads using sockets within
    # this context has been exceeded. See the +app_threads+
    # parameter of #Context.
    #
    def emthread?() EMTHREAD == @error_code; end

  end # class SocketError


  class MessageError < ZeroMQError
    # True when the exception was raised due to the library
    # returning ENOMEM.
    #
    # Only ever raised by the #Message class when it fails
    # to allocate sufficient memory to send a message.
    #
    def enomem?() ENOMEM == @error_code; end
  end

end # module ZMQ

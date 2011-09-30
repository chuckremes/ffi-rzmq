
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

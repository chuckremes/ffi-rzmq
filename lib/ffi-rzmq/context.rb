
module ZMQ

  ZMQ_INIT_STR = 'zmq_init'.freeze
  ZMQ_TERM_STR = 'zmq_term'.freeze
  ZMQ_SOCKET_STR = 'zmq_socket'.freeze unless defined? ZMQ_SOCKET_STR


  class Context
    include ZMQ::Util

    attr_reader :context, :pointer

    # Recommended to just pass 1 for +app_threads+ and +io_threads+
    # since most programs are not heavily threaded. The rule of thumb
    # is to make +app_threads+ equal to the number of application
    # threads that will be accessing 0mq sockets within this context.
    #
    # Takes a single flag (soon to be deprecated): #ZMQ::POLL
    #
    # Returns a context object. It's necessary for passing to the
    # #Socket constructor when allocating new sockets. All sockets
    # live within a context. Sockets in one context may not be accessed
    # from another context's app_threads; doing so raises an exception.
    #
    # To connect sockets between contexts, use +inproc+ or +ipc+
    # transport and set up a 0mq socket between them.
    #
    # May raise a #ContextError.
    #
    def initialize app_threads, io_threads, flags = 0
      @sockets ||= []
      @context = LibZMQ.zmq_init app_threads, io_threads, flags
      @pointer = @context
      error_check ZMQ_INIT_STR, @context.null? ? 1 : 0

      define_finalizer
    end

    # Call to release the context and any remaining data associated
    # with past sockets. This will close any sockets that remain
    # open; further calls to those sockets will raise failure
    # exceptions.
    #
    # Returns nil.
    #
    # May raise a #ContextError.
    #
    def terminate
      unless @context.null? || @context.nil?
        result_code = LibZMQ.zmq_term @context
        error_check ZMQ_TERM_STR, result_code
        @context = nil
        @sockets = nil
        remove_finalizer
      end
    end

    # Short-cut to allocate a socket for a specific context.
    #
    # Takes several +type+ values:
    #   #ZMQ::REQ
    #   #ZMQ::REP
    #   #ZMQ::PUB
    #   #ZMQ::SUB
    #   #ZMQ::PAIR
    #   #ZMQ::UPSTREAM
    #   #ZMQ::DOWNSTREAM
    #
    # Returns a #ZMQ::Socket.
    #
    # May raise a #ContextError or #SocketError.
    #
    def socket type
      sock = Socket.new @context, type
      error_check ZMQ_SOCKET_STR, sock.nil? ? 1 : 0
      sock
    end


    private

    def define_finalizer
      #ObjectSpace.define_finalizer(self, self.class.close(@context))
    end

    def remove_finalizer
      #ObjectSpace.undefine_finalizer self
    end

    def self.close context
      Proc.new { LibZMQ.zmq_term context unless context.null? }
    end
  end

end # module ZMQ

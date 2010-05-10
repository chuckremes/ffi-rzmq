
module ZMQ

  ZMQ_INIT_STR = 'zmq_init'.freeze
  ZMQ_TERM_STR = 'zmq_term'.freeze
  ZMQ_SOCKET_STR = 'zmq_socket'.freeze

  class Context
    include ZMQ::Util
    
    attr_reader :context

    def initialize app_threads, io_threads, flags
      @sockets ||= []
      @context = LibZMQ.zmq_init app_threads, io_threads, flags
      error_check ZMQ_INIT_STR, @context.nil? ? 1 : 0
    end

    def terminate
      result_code = LibZMQ.zmq_term @context
      error_check ZMQ_TERM_STR, result_code
      @context = nil
      @socket = nil
      @sockets = nil
    end

    def socket type
      @socket = Socket.new @context, type
      error_check ZMQ_SOCKET_STR, @socket.nil? ? 1 : 0
      @socket
    end
  end

end # module ZMQ

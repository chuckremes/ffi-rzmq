
module ZMQ

  #  Socket types
  PAIR = 0
  PUB = 1
  SUB = 2
  REQ = 3
  REP = 4
  XREQ = 5
  XREP = 6
  PULL = UPSTREAM = 7
  PUSH = DOWNSTREAM = 8

  #  Socket options
  HWM = 1
  SWAP = 3
  AFFINITY = 4
  IDENTITY = 5
  SUBSCRIBE = 6
  UNSUBSCRIBE = 7
  RATE = 8
  RECOVERY_IVL = 9
  MCAST_LOOP = 10
  SNDBUF = 11
  RCVBUF = 12
  RCVMORE = 13

  #  Send/recv options
  NOBLOCK = 1
  SNDMORE = 2

  #  I/O multiplexing

  POLL = 1
  POLLIN = 1
  POLLOUT = 2
  POLLERR = 4

  #  Socket errors
  EAGAIN = Errno::EAGAIN::Errno
  EINVAL = Errno::EINVAL::Errno
  ENOMEM = Errno::ENOMEM::Errno
  ENODEV = Errno::ENODEV::Errno
  EFAULT = Errno::EFAULT::Errno

  # ZMQ errors
  HAUSNUMERO     = 156384712
  EMTHREAD       = (HAUSNUMERO + 50)
  EFSM           = (HAUSNUMERO + 51)
  ENOCOMPATPROTO = (HAUSNUMERO + 52)
  ETERM          = (HAUSNUMERO + 53)

  # Rescue unknown constants and use the ZeroMQ defined values
  # Usually only happens on Windows though some don't resolve on
  # OSX too (ENOTSUP)
  ENOTSUP         = Errno::ENOTSUP::Errno rescue (HAUSNUMERO + 1)
  EPROTONOSUPPORT = Errno::EPROTONOSUPPORT::Errno rescue (HAUSNUMERO + 2)
  ENOBUFS         = Errno::ENOBUFS::Errno rescue (HAUSNUMERO + 3)
  ENETDOWN        = Errno::ENETDOWN::Errno rescue (HAUSNUMERO + 4)
  EADDRINUSE      = Errno::EADDRINUSE::Errno rescue (HAUSNUMERO + 5)
  EADDRNOTAVAIL   = Errno::EADDRNOTAVAIL::Errno rescue (HAUSNUMERO + 6)
  ECONNREFUSED    = Errno::ECONNREFUSED::Errno rescue (HAUSNUMERO + 7)
  EINPROGRESS     = Errno::EINPROGRESS::Errno rescue (HAUSNUMERO + 8)



  # These methods don't belong to any specific context. They get included
  # in the #Context, #Socket and #Poller classes.
  #
  module Util

    # Returns the +errno+ as set by the libzmq library.
    #
    def errno
      LibZMQ.zmq_errno
    end

    # Returns a string corresponding to the currently set #errno. These
    # error strings are defined by libzmq.
    #
    def error_string
      LibZMQ.zmq_strerror(errno).read_string
    end

    # Returns an array of the form [major, minor, patch] to represent the
    # version of libzmq.
    #
    def version
      major = FFI::MemoryPointer.new :int
      minor = FFI::MemoryPointer.new :int
      patch = FFI::MemoryPointer.new :int
      LibZMQ.zmq_version major, minor, patch
      [major.read_int, minor.read_int, patch.read_int]
    end


    private

    # :doc:
    # Called by most library methods to verify there were no errors during
    # operation. If any are found, raise the appropriate #ZeroMQError.
    #
    # When no error is found, this method returns +true+ which is behavior
    # used internally by #send and #recv.
    #
    def error_check source, result_code
      unless result_code.zero?
        raise_error source, result_code
      end

      # used by Socket::send/recv, ignored by others
      true
    end

    # :doc:
    # Only called on sockets in non-blocking mode.
    #
    # Checks the #errno and +result_code+ values for a failed non-blocking
    # send/recv. True only when #errno is EGAIN and +result_code+ is non-zero.
    #
    def error_check_nonblock result_code
      queue_operation = eagain? && !result_code.zero? ? false : true
      queue_operation
    end

    def raise_error source, result_code
      case source
      when ZMQ_SOCKET_STR, ZMQ_SETSOCKOPT_STR, ZMQ_GETSOCKOPT_STR, ZMQ_BIND_STR, ZMQ_CONNECT_STR, ZMQ_SEND_STR, ZMQ_RECV_STR
        raise SocketError.new source, result_code, errno, error_string
      when ZMQ_INIT_STR, ZMQ_TERM_STR
        raise ContextError.new source, result_code, errno, error_string
      when ZMQ_POLL_STR
        raise PollError.new source, result_code, errno, error_string
      else
        raise ZeroMQError.new source, result_code, -1, 
        "Source [#{source}] does not match any zmq_* strings, rc [#{result_code}], errno [#{errno}], error_string [#{error_string}]"
      end
    end

    def eagain?
      EAGAIN == errno
    end

  end # module Util

end # module ZMQ

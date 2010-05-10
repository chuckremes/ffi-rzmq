
module ZMQ

  #  Socket types
  PAIR = 0
  PUB = 1
  SUB = 2
  REQ = 3
  REP = 4
  XREQ = 5
  XREP = 6
  UPSTREAM = 7
  DOWNSTREAM = 8

  #  Socket options
  HWM = 1
  LWM = 2
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

  POLLIN = 1
  POLLOUT = 2
  POLLERR = 4

  #  Socket errors
  EAGAIN = Errno::EAGAIN::Errno
  EINVAL = Errno::EINVAL::Errno

  module Util
    # these methods don't belong to any specific context
    def errno
      LibZMQ.zmq_errno
    end

    def error_string
      LibZMQ.zmq_strerror errno
    end
    
    # Returns an array of the form [major, minor, patch] to represent the
    # version of libzmq.
    def version
      major = FFI::MemoryPointer.new :int
      minor = FFI::MemoryPointer.new :int
      patch = FFI::MemoryPointer.new :int
      LibZMQ.zmq_version major, minor, patch
      [major.read_int, minor.read_int, patch.read_int]
    end


    private

    def error_check source, result_code
      raise ZeroMQError, "ZMQ: #{source} failed with message: #{error_string}" unless result_code.zero?
      true # used by Socket::send/recv
    end

    # 
    def error_check_nonblock result_code
      queue_operation = eagain? && !result_code.zero? ? false : true
      queue_operation
    end

    def eagain?
      EAGAIN == errno
    end

  end # module Util

end # module ZMQ

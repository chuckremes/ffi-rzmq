
module ZMQ

  # These methods don't belong to any specific class. They get included
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
    # Class method! Invoke as:  ZMQ::Util.version
    #
    def self.version
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
      if result_code == -1
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
      if result_code >= 0
        true
      else
        # need to check result_code again because !eagain? could be true
        # and we need the result_code test to fail again to give the right result
        #  !eagain? is true, result_code is -1 => return false
        #  !eagain? is false, result_code is -1 => return false
        !eagain? && result_code >= 0
      end
    end

    def raise_error source, result_code
      if ['zmq_send', 'zmq_sendmsg', 'zmq_recv', 'zmq_recvmsg', 'zmq_socket', 'zmq_setsockopt', 'zmq_getsockopt', 'zmq_bind', 'zmq_connect', 'zmq_close'].include?(source)
        raise SocketError.new source, result_code, errno, error_string

      elsif ['zmq_init', 'zmq_term'].include?(source)
        raise ContextError.new source, result_code, errno, error_string

      elsif 'zmq_poll' == source
        raise PollError.new source, result_code, errno, error_string

      elsif ['zmq_msg_init', 'zmq_msg_init_data', 'zmq_msg_copy', 'zmq_msg_move'].include?(source)
        raise MessageError.new source, result_code, errno, error_string

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

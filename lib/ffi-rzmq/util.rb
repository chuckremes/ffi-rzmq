
module ZMQ

  # These methods don't belong to any specific class. They get included
  # in the #Context, #Socket and #Poller classes.
  #
  module Util
    
    # Returns true when +rc+ is greater than or equal to 0, false otherwise.
    #
    # We use the >= test because zmq_poll() returns the number of sockets
    # that had a read or write event triggered. So, a >= 0 result means
    # it succeeded.
    #
    def self.resultcode_ok? rc
      rc >= 0
    end

    # Returns the +errno+ as set by the libzmq library.
    #
    def self.errno
      LibZMQ.zmq_errno
    end

    # Returns a string corresponding to the currently set #errno. These
    # error strings are defined by libzmq.
    #
    def self.error_string
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
      if -1 == result_code
        raise_error source, result_code
      end

      # used by Socket::send/recv, ignored by others
      true
    end

    def raise_error source, result_code
      if 'zmq_init' == source || 'zmq_socket' == source
        raise ContextError.new source, result_code, ZMQ::Util.errno, ZMQ::Util.error_string

      elsif ['zmq_msg_init', 'zmq_msg_init_data', 'zmq_msg_copy', 'zmq_msg_move'].include?(source)
        raise MessageError.new source, result_code, ZMQ::Util.errno, ZMQ::Util.error_string

      else
        puts "else"
        raise ZeroMQError.new source, result_code, -1,
        "Source [#{source}] does not match any zmq_* strings, rc [#{result_code}], errno [#{ZMQ::Util.errno}], error_string [#{ZMQ::Util.error_string}]"
      end
    end

    def eagain?
      EAGAIN == ZMQ::Util.errno
    end

  end # module Util

end # module ZMQ


# Wraps the libzmq library and attaches to the functions that are
# common across the 2.x, 3.x and 4.x APIs.
#
module LibZMQ
  extend FFI::Library

  # bias the library discovery to a path inside the gem first, then
  # to the usual system paths
  inside_gem = File.join(File.dirname(__FILE__), '..', '..', 'ext')
  ZMQ_LIB_PATHS = [inside_gem, '/usr/local/lib', '/opt/local/lib', '/usr/local/homebrew/lib'].map{|path| "#{path}/libzmq.#{FFI::Platform::LIBSUFFIX}"}
  ffi_lib(ZMQ_LIB_PATHS + %w{libzmq})

  # Size_t not working properly on Windows
  find_type(:size_t) rescue typedef(:ulong, :size_t)

  # Context and misc api
  attach_function :zmq_init, [:int], :pointer
  attach_function :zmq_socket, [:pointer, :int], :pointer
  attach_function :zmq_term, [:pointer], :int
  attach_function :zmq_errno, [], :int
  attach_function :zmq_strerror, [:int], :pointer
  attach_function :zmq_version, [:pointer, :pointer, :pointer], :void

  def self.version
    unless @version
      major = FFI::MemoryPointer.new :int
      minor = FFI::MemoryPointer.new :int
      patch = FFI::MemoryPointer.new :int
      LibZMQ.zmq_version major, minor, patch
      @version = {:major => major.read_int, :minor => minor.read_int, :patch => patch.read_int}
    end

    @version
  end

  def self.version2?() version[:major] == 2 && version[:minor] >= 1  end

  def self.version3?() version[:major] == 3 end

  def self.version4?() version[:major] == 4 end


  # Message api
  attach_function :zmq_msg_init, [:pointer], :int
  attach_function :zmq_msg_init_size, [:pointer, :size_t], :int
  attach_function :zmq_msg_init_data, [:pointer, :pointer, :size_t, :pointer, :pointer], :int
  attach_function :zmq_msg_close, [:pointer], :int
  attach_function :zmq_msg_data, [:pointer], :pointer
  attach_function :zmq_msg_size, [:pointer], :size_t
  attach_function :zmq_msg_copy, [:pointer, :pointer], :int
  attach_function :zmq_msg_move, [:pointer, :pointer], :int

  # Used for casting pointers back to the struct
  #
  class Msg < FFI::Struct
    layout :content,  :pointer,
    :flags,    :uint8,
    :vsm_size, :uint8,
    :vsm_data, [:uint8, 30]
  end # class Msg

  # Socket api
  attach_function :zmq_setsockopt, [:pointer, :int, :pointer, :int], :int
  attach_function :zmq_bind, [:pointer, :string], :int
  attach_function :zmq_connect, [:pointer, :string], :int
  attach_function :zmq_close, [:pointer], :int

  # Poll api
  attach_function :zmq_poll, [:pointer, :int, :long], :int

  module PollItemLayout
    def self.included(base)
      base.class_eval do
        layout :socket,  :pointer,
        :fd,    :int,
        :events, :short,
        :revents, :short
      end
    end
  end # module PollItemLayout

  class PollItem < FFI::Struct
    include PollItemLayout

    def socket() self[:socket]; end

    def readable?
      (self[:revents] & ZMQ::POLLIN) > 0
    end

    def writable?
      (self[:revents] & ZMQ::POLLOUT) > 0
    end

    def both_accessible?
      readable? && writable?
    end

    def inspect
      "socket [#{socket}], fd [#{self[:fd]}], events [#{self[:events]}], revents [#{self[:revents]}]"
    end

    def to_s; inspect; end
  end # class PollItem

end


# Attaches to those functions specific to the 2.x API
#
if LibZMQ.version2?
  puts "loading version #{LibZMQ.version.inspect}"
  module LibZMQ
    # Socket api
    # @blocking = true is a hint to FFI that the following (and only the following)
    # function may block, therefore it should release the GIL before calling it.
    # This can aid in situations where the function call will/may block and another
    # thread within the lib may try to call back into the ruby runtime. Failure to
    # release the GIL will result in a hang; the hint *may* allow things to run
    # smoothly for Ruby runtimes hampered by a GIL.
    #
    # This is really only honored by the MRI implementation.
    attach_function :zmq_getsockopt, [:pointer, :int, :pointer, :pointer], :int
    @blocking = true
    attach_function :zmq_recv, [:pointer, :pointer, :int], :int
    @blocking = true
    attach_function :zmq_send, [:pointer, :pointer, :int], :int
    @blocking = true
    attach_function :zmq_device, [:int, :pointer, :pointer], :int
  end
end


# Attaches to those functions specific to the 3.x and 4.x APIs
#
if LibZMQ.version3? || LibZMQ.version4?
  puts "loading version #{LibZMQ.version.inspect}"
  module LibZMQ
    # Socket api
    attach_function :zmq_getsockopt, [:pointer, :int, :pointer, :pointer], :int
    attach_function :zmq_recvmsg, [:pointer, :pointer, :int], :int
    attach_function :zmq_recv, [:pointer, :pointer, :size_t, :int], :int
    attach_function :zmq_sendmsg, [:pointer, :pointer, :int], :int
    attach_function :zmq_send, [:pointer, :pointer, :size_t, :int], :int
  end
end


# Sanity check; print an error and exit if we are trying to load an unsupported
# version of libzmq.
#
unless LibZMQ.version2? || LibZMQ.version3? || LibZMQ.version4?
  hash = LibZMQ.version
  version = "#{hash[:major]}.#{hash[:minor]}.#{hash[:patch]}"
  STDERR.puts "Unable to load this gem. The libzmq version #{version} is incompatible with ffi-rzmq."
  exit 255
end

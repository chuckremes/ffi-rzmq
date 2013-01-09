module ZMQ

  # Wraps the libzmq library and attaches to the functions that are
  # common across the 2.x and 3.x APIs.
  #
  module LibZMQ
    extend FFI::Library

    begin
      # bias the library discovery to a path inside the gem first, then
      # to the usual system paths
      inside_gem = File.join(File.dirname(__FILE__), '..', '..', 'ext')
      if FFI::Platform::IS_WINDOWS
        local_path=ENV['PATH'].split(';')
      else
        local_path=ENV['PATH'].split(':')
      end
      ZMQ_LIB_PATHS = [
        inside_gem, '/usr/local/lib', '/opt/local/lib', '/usr/local/homebrew/lib', '/usr/lib64'
      ].map{|path| "#{path}/libzmq.#{FFI::Platform::LIBSUFFIX}"}
      ffi_lib(ZMQ_LIB_PATHS + %w{libzmq})
    rescue LoadError
      if ZMQ_LIB_PATHS.push(*local_path).any? {|path|
        File.file? File.join(path, "libzmq.#{FFI::Platform::LIBSUFFIX}")}
        warn "Unable to load this gem. The libzmq library exists, but cannot be loaded."
        warn "If this is Windows:"
        warn "-  Check that you have MSVC runtime installed or statically linked"
        warn "-  Check that your DLL is compiled for #{FFI::Platform::ADDRESS_SIZE} bit"
      else
        warn "Unable to load this gem. The libzmq library (or DLL) could not be found."
        warn "If this is a Windows platform, make sure libzmq.dll is on the PATH."
        warn "If the DLL was built with mingw, make sure the other two dependent DLLs,"
        warn "libgcc_s_sjlj-1.dll and libstdc++6.dll, are also on the PATH."
        warn "For non-Windows platforms, make sure libzmq is located in this search path:"
        warn ZMQ_LIB_PATHS.inspect
      end
      raise LoadError, "The libzmq library (or DLL) could not be loaded"
    end
    # Size_t not working properly on Windows
    find_type(:size_t) rescue typedef(:ulong, :size_t)

    # Context and misc api
    #
    # @blocking = true is a hint to FFI that the following (and only the following)
    # function may block, therefore it should release the GIL before calling it.
    # This can aid in situations where the function call will/may block and another
    # thread within the lib may try to call back into the ruby runtime. Failure to
    # release the GIL will result in a hang; the hint *may* allow things to run
    # smoothly for Ruby runtimes hampered by a GIL.
    #
    # This is really only honored by the MRI implementation but it *is* necessary
    # otherwise the runtime hangs (and requires a kill -9 to terminate)
    #
    @blocking = true
    attach_function :zmq_version, [:pointer, :pointer, :pointer], :void
    @blocking = true
    attach_function :zmq_errno, [], :int
    @blocking = true
    attach_function :zmq_strerror, [:int], :pointer

    def self.version
      if @version.nil?
        major = FFI::MemoryPointer.new :int
        minor = FFI::MemoryPointer.new :int
        patch = FFI::MemoryPointer.new :int
        LibZMQ.zmq_version major, minor, patch
        @version = {:major => major.read_int, :minor => minor.read_int, :patch => patch.read_int}
      end

      @version
    end

    def self.version2?() version[:major] == 2 && version[:minor] >= 1  end

    def self.version3?() version[:major] == 3 && version[:minor] >= 2 end

    # Context initialization and destruction
    @blocking = true
    attach_function :zmq_init, [:int], :pointer
    @blocking = true
    attach_function :zmq_term, [:pointer], :int

    # Message API
    @blocking = true
    attach_function :zmq_msg_init, [:pointer], :int
    @blocking = true
    attach_function :zmq_msg_init_size, [:pointer, :size_t], :int
    @blocking = true
    attach_function :zmq_msg_init_data, [:pointer, :pointer, :size_t, :pointer, :pointer], :int
    @blocking = true
    attach_function :zmq_msg_close, [:pointer], :int
    @blocking = true
    attach_function :zmq_msg_data, [:pointer], :pointer
    @blocking = true
    attach_function :zmq_msg_size, [:pointer], :size_t
    @blocking = true
    attach_function :zmq_msg_copy, [:pointer, :pointer], :int
    @blocking = true
    attach_function :zmq_msg_move, [:pointer, :pointer], :int

    # Used for casting pointers back to the struct
    #
    class Msg < FFI::Struct
      layout :content,  :pointer,
      :flags,    :uint8,
      :vsm_size, :uint8,
      :vsm_data, [:uint8, 30]
    end # class Msg

    # Socket API
    @blocking = true
    attach_function :zmq_socket, [:pointer, :int], :pointer
    @blocking = true
    attach_function :zmq_setsockopt, [:pointer, :int, :pointer, :int], :int
    @blocking = true
    attach_function :zmq_getsockopt, [:pointer, :int, :pointer, :pointer], :int
    @blocking = true
    attach_function :zmq_bind, [:pointer, :string], :int
    @blocking = true
    attach_function :zmq_connect, [:pointer, :string], :int
    @blocking = true
    attach_function :zmq_close, [:pointer], :int

    # Device API
    @blocking = true
    attach_function :zmq_device, [:int, :pointer, :pointer], :int

    # Poll API
    @blocking = true
    attach_function :zmq_poll, [:pointer, :int, :long], :int

    module PollItemLayout
      def self.included(base)
        if FFI::Platform::IS_WINDOWS && FFI::Platform::ADDRESS_SIZE==64
          # On Windows, zmq.h defines fd as a SOCKET, which is 64 bits on x64.
          fd_type=:uint64
        else
          fd_type=:int
        end
        base.class_eval do
          layout :socket,  :pointer,
            :fd,    fd_type,
            :events, :short,
            :revents, :short
        end
      end
    end # module PollItemLayout

    class PollItem < FFI::Struct
      include PollItemLayout

      def socket() self[:socket]; end

      def fd() self[:fd]; end

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
        "socket [#{socket}], fd [#{fd}], events [#{self[:events]}], revents [#{self[:revents]}]"
      end

      def to_s; inspect; end
    end # class PollItem

  end


  # Attaches to those functions specific to the 2.x API
  #
  if LibZMQ.version2?

    module LibZMQ
      # Socket api
      @blocking = true
      attach_function :zmq_recv, [:pointer, :pointer, :int], :int
      @blocking = true
      attach_function :zmq_send, [:pointer, :pointer, :int], :int
    end
  end


  # Attaches to those functions specific to the 3.x API
  #
  if LibZMQ.version3?

    module LibZMQ
      # New Context API
      @blocking = true
      attach_function :zmq_ctx_new, [], :pointer
      @blocking = true
      attach_function :zmq_ctx_destroy, [:pointer], :int
      @blocking = true
      attach_function :zmq_ctx_set, [:pointer, :int, :int], :int
      @blocking = true
      attach_function :zmq_ctx_get, [:pointer, :int], :int

      # Message API
      @blocking = true
      attach_function :zmq_msg_send, [:pointer, :pointer, :int], :int
      @blocking = true
      attach_function :zmq_msg_recv, [:pointer, :pointer, :int], :int
      @blocking = true
      attach_function :zmq_msg_more, [:pointer], :int
      @blocking = true
      attach_function :zmq_msg_get, [:pointer, :int], :int
      @blocking = true
      attach_function :zmq_msg_set, [:pointer, :int, :int], :int

      # Monitoring API
      # zmq_ctx_set_monitor is no longer supported as of version >= 3.2.1
      # replaced by zmq_socket_monitor
      if LibZMQ.version[:minor] > 2 || (LibZMQ.version[:minor] == 2 && LibZMQ.version[:patch] >= 1)
        @blocking = true
        attach_function :zmq_socket_monitor, [:pointer, :pointer, :int], :int
      else
        @blocking = true
        attach_function :zmq_ctx_set_monitor, [:pointer, :pointer], :int
      end

      # Socket API
      @blocking = true
      attach_function :zmq_unbind, [:pointer, :string], :int
      @blocking = true
      attach_function :zmq_disconnect, [:pointer, :string], :int
      @blocking = true
      attach_function :zmq_recvmsg, [:pointer, :pointer, :int], :int
      @blocking = true
      attach_function :zmq_recv, [:pointer, :pointer, :size_t, :int], :int
      @blocking = true
      attach_function :zmq_sendmsg, [:pointer, :pointer, :int], :int
      @blocking = true
      attach_function :zmq_send, [:pointer, :pointer, :size_t, :int], :int

      module EventDataLayout
        def self.included(base)
          base.class_eval do
            layout :event, :int,
            :addr,  :string,
            :field2,    :int
          end
        end
      end # module EventDataLayout

      class EventData < FFI::Struct
        include EventDataLayout

        def event() self[:event]; end

        def addr() self[:addr]; end
        alias :address :addr

        def fd() self[:field2]; end
        alias :err :fd
        alias :interval :fd

        def inspect
          "event [#{event}], addr [#{addr}], fd [#{fd}], field2 [#{fd}]"
        end

        def to_s; inspect; end
      end # class EventData

    end
  end


  # Sanity check; print an error and exit if we are trying to load an unsupported
  # version of libzmq.
  #
  unless LibZMQ.version2? || LibZMQ.version3?
    hash = LibZMQ.version
    version = "#{hash[:major]}.#{hash[:minor]}.#{hash[:patch]}"
    raise LoadError, "The libzmq version #{version} is incompatible with ffi-rzmq."
  end

end # module ZMQ

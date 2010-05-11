require 'ffi' # external gem

module LibC
  extend FFI::Library
  LINUX = ["libc.so", "/lib/libc.so", "/lib/libc.so.6", "/usr/lib/libc.so", "/usr/lib/libc.so.6"]
  OSX = ["libc.dylib", "/usr/lib/libc.dylib"]
  WINDOWS = []
  ffi_lib(LINUX + OSX + WINDOWS)
  
  # memory allocators
  attach_function :malloc, [:size_t], :pointer
  attach_function :calloc, [:size_t], :pointer
  attach_function :valloc, [:size_t], :pointer
  attach_function :realloc, [:pointer, :size_t], :pointer
  attach_function :free, [:pointer], :void
  
  # memory movers
  attach_function :memcpy, [:pointer, :pointer, :size_t], :pointer
  attach_function :bcopy, [:pointer, :pointer, :size_t], :void
  
end # module LibC

module LibZMQ
  extend FFI::Library
  LINUX = ["libzmq.so", "/usr/local/lib/libzmq.so", "/opt/local/lib/libzmq.so"]
  OSX = ["libzmq.dylib", "/usr/local/lib/libzmq.dylib", "/opt/local/lib/libzmq.dylib"]
  WINDOWS = []
  ffi_lib(LINUX + OSX + WINDOWS)

  # Misc
  attach_function :zmq_version, [:pointer, :pointer, :pointer], :void
  
  # Context and misc api
  attach_function :zmq_init, [:int, :int, :int], :pointer
  attach_function :zmq_socket, [:pointer, :int], :pointer
  attach_function :zmq_term, [:pointer], :int
  attach_function :zmq_errno, [], :int
  attach_function :zmq_strerror, [:int], :pointer

  # Message api
  attach_function :zmq_msg_init, [:pointer], :int
  attach_function :zmq_msg_init_size, [:pointer, :size_t], :int
  callback :message_deallocator, [:pointer, :pointer], :void
  attach_function :zmq_msg_init_data, [:pointer, :pointer, :size_t, :message_deallocator, :pointer], :int
  attach_function :zmq_msg_close, [:pointer], :int
  attach_function :zmq_msg_data, [:pointer], :pointer
  attach_function :zmq_msg_size, [:pointer], :size_t
  attach_function :zmq_msg_copy, [:pointer, :pointer], :int
  attach_function :zmq_msg_move, [:pointer, :pointer], :int

  MessageDeallocator = Proc.new do |data_ptr, hint_ptr|
    LibC.free data_ptr
  end

  module MsgLayout
    def self.included(base)
      base.class_eval do
        layout :content,  :pointer,
        :flags,    :uint8,
        :vsm_size, :uint8,
        :vsm_data, [:uint8, 30]
      end
    end
  end # module MsgLayout

  # Used for casting pointers back to the struct
  class Msg < FFI::Struct
    include MsgLayout
  end # class Msg
    

  # Socket api

  attach_function :zmq_setsockopt, [:pointer, :int, :pointer, :int], :int
  attach_function :zmq_bind, [:pointer, :string], :int
  attach_function :zmq_connect, [:pointer, :string], :int
  attach_function :zmq_send, [:pointer, :pointer, :int], :int
  attach_function :zmq_recv, [:pointer, :pointer, :int], :int
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
    
    def readable?
      !(self[:revents] & ZMQ::POLLIN).zero?
    end
    
    def writable?
      !(self[:revents] & ZMQ::POLLOUT).zero?
    end
    
    def both_accessible?
      readable? && writable?
    end
    
    def inspect
      "socket [#{self[:socket]}], fd [#{self[:fd]}], events [#{self[:events]}], revents [#{self[:revents]}]"
    end
    
    def to_s; inspect; end
  end # class PollItem

end # module ZMQ

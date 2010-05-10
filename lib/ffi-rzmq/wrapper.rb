require 'ffi' # external gem

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
    data_ptr.free if data_ptr.respond_to? :free
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
  end

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

end # module ZMQ

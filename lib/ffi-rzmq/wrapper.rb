require 'ffi'

module LibZMQ
  extend FFI::Library
  ffi_lib "libzmq.so"

  # initialize, socket
  attach_function :zmq_init, [:int, :int, :int], :pointer
  attach_function :zmq_socket, [:pointer, :int], :pointer

  # message api
  class Msg_t < FFI::Struct
    layout :content,  :pointer,
    :flags,    :uint8,
    :vsm_size, :uint8,
    :vsm_data, [:uint8, 30]

  end # class Msg_t

  attach_function :zmq_msg_init, [:pointer], :int
  attach_function :zmq_msg_init_size, [:pointer, :size_t], :int
  attach_function :zmq_msg_init_data, [:pointer, :pointer, :size_t, :pointer, :pointer], :int
  attach_function :zmq_msg_close, [:pointer], :int
  attach_function :zmq_msg_data, [:pointer], :pointer
  attach_function :zmq_msg_size, [:pointer], :size_t
  attach_function :zmq_msg_copy, [:pointer, :pointer], :int
  attach_function :zmq_msg_move, [:pointer, :pointer], :int

  # setsockopt, bind, connect, send, recv, close

  attach_function :zmq_setsockopt, [:pointer, :int, :pointer, :int], :int
  attach_function :zmq_bind, [:pointer, :string], :int
  attach_function :zmq_connect, [:pointer, :string], :int
  attach_function :zmq_send, [:pointer, :pointer, :int], :int
  attach_function :zmq_recv, [:pointer, :pointer, :int], :int
  attach_function :zmq_close, [:pointer], :int


  # Constants
  
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
end # module ZMQ

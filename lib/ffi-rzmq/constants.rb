module ZMQ

  #  Socket types
  PAIR = 0
  PUB = 1
  SUB = 2
  REQ = 3
  REP = 4
  DEALER = XREQ = 5
  ROUTER = XREP = 6
  PULL = UPSTREAM = 7
  PUSH = DOWNSTREAM = 8

  SocketTypeNameMap = {
    PAIR => "PAIR",
    PUB => "PUB",
    SUB => "SUB",
    REQ => "REQ",
    REP => "REP",
    ROUTER => "ROUTER",
    DEALER => "DEALER",
    PULL => "PULL",
    PUSH => "PUSH"
  }

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
  FD = 14
  EVENTS = 15
  TYPE = 16
  LINGER = 17
  RECONNECT_IVL = 18
  BACKLOG = 19
  RECOVERY_IVL_MSEC = 20
  RECONNECT_IVL_MAX = 21

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

  #  Device Types
  STREAMER = 1
  FORWARDER = 2
  QUEUE = 3

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
end # module ZMQ


if LibZMQ.version3? || LibZMQ.version4?
  module ZMQ
    # Socket types
    remove_const UPSTREAM
    remove_const DOWNSTREAM
    remove_const ROUTER
    remove_const DEALER
    XPUB = 9
    XSUB = 10
    ROUTER = 11
    DEALER = 12

    # devices
    remove_const STREAMER
    remove_const FORWARDER
    remove_const QUEUE
    
    # Socket options
    remove_const MCAST_LOOP
    remove_const SWAP
    remove_const RECOVERY_IVL_MSEC
    MAXMSGSIZE = 22
    SNDHWM = 23
    RCVHWM = 24
    MULTICAST_HOPS = 25
    RCVTIMEO = 27
    SNDTIMEO = 28
    RCVLABEL = 29
    
    # Send/recv options
    remove_const NOBLOCK
    DONTWAIT = 1
    SNDLABEL = 4
    
    
    # Socket & other errors
    ENOTSOCK = Errno::ENOTSOCK::Errno rescue (HAUSNUMERO + 9)
    EINTR = Errnow::EINTR::Errno rescue (HAUSNUMERO + 10)
    EMFILE = Errno::EMFILE::Errno
    EMTHREAD = HAUSNUMERO + 54
    
    if LibZMQ.version4?
      remove_const IDENTITY
    end
  end
end
module ZMQ
  # Set up all of the constants that are *common* to all API
  # versions
  
  #  Socket types
  PAIR = 0
  PUB = 1
  SUB = 2
  REQ = 3
  REP = 4
  XREQ = 5
  XREP = 6
  PULL = 7
  PUSH = 8

  SocketTypeNameMap = {
    PAIR => "PAIR",
    PUB => "PUB",
    SUB => "SUB",
    REQ => "REQ",
    REP => "REP",
    PULL => "PULL",
    PUSH => "PUSH",
    XREQ => "XREQ",
    XREP => "XREP"
  }

  #  Socket options
  AFFINITY = 4
  SUBSCRIBE = 6
  UNSUBSCRIBE = 7
  RATE = 8
  RECOVERY_IVL = 9
  SNDBUF = 11
  RCVBUF = 12
  RCVMORE = 13
  FD = 14
  EVENTS = 15
  TYPE = 16
  LINGER = 17
  RECONNECT_IVL = 18
  BACKLOG = 19
  RECONNECT_IVL_MAX = 21

  #  Send/recv options
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
  ENOTSOCK        = Errno::ENOTSOCK::Errno rescue (HAUSNUMERO + 9)
  EINTR           = Errno::EINTR::Errno rescue (HAUSNUMERO + 10)
end # module ZMQ


if ZMQ::LibZMQ.version2?
  module ZMQ
    # Socket types
    UPSTREAM = PULL
    DOWNSTREAM = PUSH
    DEALER = XREQ
    ROUTER = XREP

    SocketTypeNameMap[ROUTER] = 'ROUTER'
    SocketTypeNameMap[DEALER] = 'DEALER'

    #  Device Types
    STREAMER = 1
    FORWARDER = 2
    QUEUE = 3

    # Socket options
    HWM = 1
    IDENTITY = 5
    MCAST_LOOP = 10
    SWAP = 3
    RECOVERY_IVL_MSEC = 20

    # Send/recv options
    NOBLOCK = 1
    NonBlocking = NOBLOCK
  end
end # version2?


if ZMQ::LibZMQ.version3?
  module ZMQ
    # Socket types
    XPUB = 9
    XSUB = 10
    DEALER = XREQ
    ROUTER = XREP

    SocketTypeNameMap[ROUTER] = 'ROUTER'
    SocketTypeNameMap[DEALER] = 'DEALER'
    SocketTypeNameMap[XPUB] = 'XPUB'
    SocketTypeNameMap[XSUB] = 'XSUB'

    # Socket options
    IDENTITY = 5
    MAXMSGSIZE = 22
    SNDHWM = 23
    RCVHWM = 24
    MULTICAST_HOPS = 25
    RCVTIMEO = 27
    SNDTIMEO = 28
    IPV4ONLY = 31

    # Send/recv options
    DONTWAIT = 1
    SNDLABEL = 4
    NonBlocking = DONTWAIT

    # Socket & other errors
    EMFILE = Errno::EMFILE::Errno
  end
end # version3?

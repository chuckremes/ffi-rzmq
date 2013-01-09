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
  RCVTIMEO = 27
  SNDTIMEO = 28

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
  EINTR  = Errno::EINTR::Errno

  # ZMQ errors
  HAUSNUMERO     = 156384712
  EFSM           = (HAUSNUMERO + 51)
  ENOCOMPATPROTO = (HAUSNUMERO + 52)
  ETERM          = (HAUSNUMERO + 53)
  EMTHREAD       = (HAUSNUMERO + 54)

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
  EMSGSIZE        = Errno::EMSGSIZE::Errno rescue (HAUSNUMERO + 10)
  EAFNOSUPPORT    = Errno::EAFNOSUPPORT::Errno rescue (HAUSNUMERO + 11)
  ENETUNREACH     = Errno::ENETUNREACH::Errno rescue (HAUSNUMERO + 12)
  ECONNABORTED    = Errno::ECONNABORTED::Errno rescue (HAUSNUMERO + 13)
  ECONNRESET      = Errno::ECONNRESET::Errno rescue (HAUSNUMERO + 14)
  ENOTCONN        = Errno::ENOTCONN::Errno rescue (HAUSNUMERO + 15)
  ETIMEDOUT       = Errno::ETIMEDOUT::Errno rescue (HAUSNUMERO + 16)
  EHOSTUNREACH    = Errno::EHOSTUNREACH::Errno rescue (HAUSNUMERO + 17)
  ENETRESET       = Errno::ENETRESET::Errno rescue (HAUSNUMERO + 18)

  #  Device Types
  STREAMER = 1
  FORWARDER = 2
  QUEUE = 3
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

    # Context options
    IO_THREADS     = 1
    MAX_SOCKETS    = 2
    IO_THREADS_DFLT = 1
    MAX_SOCKETS_DFLT = 1024

    # Socket options
    IDENTITY       = 5
    MAXMSGSIZE     = 22
    SNDHWM         = 23
    RCVHWM         = 24
    MULTICAST_HOPS = 25
    IPV4ONLY       = 31
    LAST_ENDPOINT  = 32
    ROUTER_BEHAVIOR = 33
    TCP_KEEPALIVE   = 34
    TCP_KEEPALIVE_CNT = 35
    TCP_KEEPALIVE_IDLE = 36
    TCP_KEEPALIVE_INTVL = 37
    TCP_ACCEPT_FILTER = 38
    
    # Message options
    MORE = 1

    # Send/recv options
    DONTWAIT       = 1
    SNDLABEL       = 4
    NonBlocking    = DONTWAIT

    # Socket events and monitoring
    EVENT_CONNECTED     = 1
    EVENT_CONNECT_DELAYED = 2
    EVENT_CONNECT_RETRIED = 4
    EVENT_LISTENING = 8
    EVENT_BIND_FAILED = 16
    EVENT_ACCEPTED = 32
    EVENT_ACCEPT_FAILED = 64
    EVENT_CLOSED = 128
    EVENT_CLOSE_FAILED = 256
    EVENT_DISCONNECTED = 512
    EVENT_ALL = EVENT_CONNECTED | EVENT_CONNECT_DELAYED | EVENT_CONNECT_RETRIED |
                EVENT_LISTENING | EVENT_BIND_FAILED | EVENT_ACCEPTED |
                EVENT_ACCEPT_FAILED | EVENT_CLOSED | EVENT_CLOSE_FAILED |
                EVENT_DISCONNECTED

    # Socket & other errors
    EMFILE = Errno::EMFILE::Errno
  end
end # version3?

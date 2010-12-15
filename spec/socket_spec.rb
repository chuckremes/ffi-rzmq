
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Socket do

    context "when initializing" do
      before(:all) { @ctx = Context.new }
      after(:all) { @ctx.terminate }


      it "should raise an error for a nil context" do
        lambda { Socket.new(FFI::Pointer::NULL, ZMQ::REQ) }.should raise_exception(ZMQ::ContextError)
      end

      [ZMQ::REQ, ZMQ::REP, ZMQ::XREQ, ZMQ::XREP, ZMQ::PUB, ZMQ::SUB, ZMQ::PUSH, ZMQ::PULL, ZMQ::PAIR].each do |socket_type|

        it "should not raise an error for a #{ZMQ::SocketTypeNameMap[socket_type]} socket type" do
          sock = nil
          lambda { sock = Socket.new(@ctx.pointer, socket_type) }.should_not raise_error
          sock.close
        end
      end # each socket_type

      it "should set the :socket accessor to the raw socket allocated by libzmq" do
        socket = mock('socket')
        socket.stub!(:null? => false)
        LibZMQ.should_receive(:zmq_socket).and_return(socket)

        sock = Socket.new(@ctx.pointer, ZMQ::REQ)
        sock.socket.should == socket
      end

      it "should define a finalizer on this object" do
        ObjectSpace.should_receive(:define_finalizer).at_least(1)
        sock = Socket.new(@ctx.pointer, ZMQ::REQ)
        sock.close
      end
    end # context initializing
    
    
    context "calling close" do
      before(:all) { @ctx = Context.new }
      after(:all) { @ctx.terminate }

      it "should call LibZMQ.close only once" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ
        raw_socket = sock.socket

        LibZMQ.should_receive(:close).with(raw_socket)
        sock.close
        sock.close
        LibZMQ.close raw_socket # *really close it otherwise the context will block indefinitely
      end
    end # context calling close


    context "identity=" do
      before(:all) { @ctx = Context.new }
      after(:all) { @ctx.terminate }

      it "should raise an exception for identities in excess of 255 bytes" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ

        lambda { sock.identity = ('a' * 256) }.should raise_exception(ZMQ::SocketError)
        sock.close
      end

      it "should raise an exception for identities of length 0" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ

        lambda { sock.identity = '' }.should raise_exception(ZMQ::SocketError)
        sock.close
      end

      it "should NOT raise an exception for identities of 1 byte" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ

        lambda { sock.identity = 'a' }.should_not raise_exception(ZMQ::SocketError)
        sock.close
      end

      it "should NOT raise an exception for identities of 255 bytes" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ

        lambda { sock.identity = ('a' * 255) }.should_not raise_exception(ZMQ::SocketError)
        sock.close
      end

      it "should convert numeric identities to strings" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ

        sock.identity = 7
        sock.identity.should == '7'
        sock.close
      end
    end # context identity=


    [ZMQ::REQ, ZMQ::REP, ZMQ::XREQ, ZMQ::XREP, ZMQ::PUB, ZMQ::SUB, ZMQ::PUSH, ZMQ::PULL, ZMQ::PAIR].each do |socket_type|

      context "#setsockopt for a #{ZMQ::SocketTypeNameMap[socket_type]} socket" do
        before(:all) { @ctx = Context.new }
        after(:all) { @ctx.terminate }

        let(:socket) do
          Socket.new @ctx.pointer, socket_type
        end

        after(:each) do
          socket.close
        end


        context "using option ZMQ::SUBSCRIBE" do
          if ZMQ::SUB == socket_type
            it "should *not* raise a ZMQ::SocketError" do
              lambda { socket.setsockopt(ZMQ::SUBSCRIBE, "topic.string") }.should_not raise_error(SocketError)
            end
          else
            it "should raise a ZMQ::SocketError" do
              lambda { socket.setsockopt(ZMQ::SUBSCRIBE, "topic.string") }.should raise_error(SocketError)
            end
          end
        end # context using option ZMQ::SUBSCRIBE


        context "using option ZMQ::UNSUBSCRIBE" do
          if ZMQ::SUB == socket_type
            it "should *not* raise a ZMQ::SocketError given a topic string that was previously subscribed" do
              socket.setsockopt ZMQ::SUBSCRIBE, "topic.string"
              lambda { socket.setsockopt(ZMQ::UNSUBSCRIBE, "topic.string") }.should_not raise_error(SocketError)
            end

#            it "should raise a ZMQ::SocketError given a topic string that was never subscribed" do
#              socket.setsockopt ZMQ::SUBSCRIBE, "topic.string"
#              lambda { socket.setsockopt(ZMQ::UNSUBSCRIBE, "unknown") }.should raise_error(SocketError)
#            end
          else
            it "should raise a ZMQ::SocketError" do
              lambda { socket.setsockopt(ZMQ::UNSUBSCRIBE, "topic.string") }.should raise_error(SocketError)
            end
          end
        end # context using option ZMQ::UNSUBSCRIBE


        context "using option ZMQ::HWM" do
          it "should set the high water mark given a positive value" do
            hwm = 4
            socket.setsockopt ZMQ::HWM, hwm
            socket.getsockopt(ZMQ::HWM).should == hwm
          end

          it "should convert a negative value to a positive value" do
            hwm = -4
            socket.setsockopt ZMQ::HWM, hwm
            socket.getsockopt(ZMQ::HWM).should == hwm.abs
          end
        end # context using option ZMQ::HWM


        context "using option ZMQ::SWAP" do
          it "should set the swap value given a positive value" do
            swap = 10_000
            socket.setsockopt ZMQ::SWAP, swap
            socket.getsockopt(ZMQ::SWAP).should == swap
          end

          it "should raise a SocketError given a negative value" do
            swap = -10_000
            lambda { socket.setsockopt(ZMQ::SWAP, swap) }.should raise_error(SocketError)
          end
        end # context using option ZMQ::SWP


        context "using option ZMQ::AFFINITY" do
          it "should set the affinity value given a positive value" do
            affinity = 3
            socket.setsockopt ZMQ::AFFINITY, affinity
            socket.getsockopt(ZMQ::AFFINITY).should == affinity
          end

          it "should set the affinity value as a positive value given a negative value" do
            affinity = -3
            socket.setsockopt ZMQ::AFFINITY, affinity
            socket.getsockopt(ZMQ::AFFINITY).should == affinity.abs
          end
        end # context using option ZMQ::AFFINITY


        context "using option ZMQ::IDENTITY" do
          it "should set the identity given any string under 255 characters" do
            length = 4
            (1..255).each do |length|
              identity = 'a' * length
              socket.setsockopt ZMQ::IDENTITY, identity
              socket.getsockopt(ZMQ::IDENTITY).should == identity
            end
          end

          it "should raise a SocketError given a string 256 characters or longer" do
            identity = 'a' * 256
            lambda { socket.setsockopt(ZMQ::IDENTITY, identity) }.should raise_error(SocketError)
          end
        end # context using option ZMQ::IDENTITY


        context "using option ZMQ::RATE" do
          it "should set the multicast send rate given a positive value" do
            rate = 200
            socket.setsockopt ZMQ::RATE, rate
            socket.getsockopt(ZMQ::RATE).should == rate
          end

          it "should raise a SocketError given a negative value" do
            rate = -200
            lambda { socket.setsockopt ZMQ::RATE, rate }.should raise_error(SocketError)
          end
        end # context using option ZMQ::RATE


        context "using option ZMQ::RECOVERY_IVL" do
          it "should set the multicast recovery buffer measured in seconds given a positive value" do
            rate = 200
            socket.setsockopt ZMQ::RECOVERY_IVL, rate
            socket.getsockopt(ZMQ::RECOVERY_IVL).should == rate
          end

          it "should raise a SocketError given a negative value" do
            rate = -200
            lambda { socket.setsockopt ZMQ::RECOVERY_IVL, rate }.should raise_error(SocketError)
          end
        end # context using option ZMQ::RECOVERY_IVL


        context "using option ZMQ::MCAST_LOOP" do
          it "should enable the multicast loopback given a true value" do
            socket.setsockopt ZMQ::MCAST_LOOP, true
            socket.getsockopt(ZMQ::MCAST_LOOP).should be_true
          end

          it "should disable the multicast loopback given a false value" do
            socket.setsockopt ZMQ::MCAST_LOOP, false
            socket.getsockopt(ZMQ::MCAST_LOOP).should be_false
          end
        end # context using option ZMQ::MCAST_LOOP


        context "using option ZMQ::SNDBUF" do
          it "should set the OS send buffer given a positive value" do
            size = 100
            socket.setsockopt ZMQ::SNDBUF, size
            socket.getsockopt(ZMQ::SNDBUF).should == size
          end

          it "should set the OS send buffer to a positive value given a false value" do
            size = -100
            socket.setsockopt ZMQ::SNDBUF, size
            socket.getsockopt(ZMQ::SNDBUF).should == size.abs
          end
        end # context using option ZMQ::SNDBUF


        context "using option ZMQ::RCVBUF" do
          it "should set the OS receive buffer given a positive value" do
            size = 100
            socket.setsockopt ZMQ::RCVBUF, size
            socket.getsockopt(ZMQ::RCVBUF).should == size
          end

          it "should set the OS receive buffer to a positive value given a false value" do
            size = -100
            socket.setsockopt ZMQ::RCVBUF, size
            socket.getsockopt(ZMQ::RCVBUF).should == size.abs
          end
        end # context using option ZMQ::RCVBUF


        context "using option ZMQ::LINGER" do
          it "should set the socket message linger option measured in milliseconds given a positive value" do
            value = 200
            socket.setsockopt ZMQ::LINGER, value
            socket.getsockopt(ZMQ::LINGER).should == value
          end

          it "should set the socket message linger option to 0 for dropping packets" do
            value = 0
            socket.setsockopt ZMQ::LINGER, value
            socket.getsockopt(ZMQ::LINGER).should == value
          end

          it "should default to a value of -1" do
            value = -1
            socket.getsockopt(ZMQ::LINGER).should == value
          end
        end # context using option ZMQ::LINGER


        context "using option ZMQ::RECONNECT_IVL" do
          it "should set the time interval for reconnecting disconnected sockets measured in milliseconds given a positive value" do
            value = 200
            socket.setsockopt ZMQ::RECONNECT_IVL, value
            socket.getsockopt(ZMQ::RECONNECT_IVL).should == value
          end

          it "should default to a value of 100" do
            value = 100
            socket.getsockopt(ZMQ::RECONNECT_IVL).should == value
          end
        end # context using option ZMQ::RECONNECT_IVL


        context "using option ZMQ::BACKLOG" do
          it "should set the maximum number of pending socket connections given a positive value" do
            value = 200
            socket.setsockopt ZMQ::BACKLOG, value
            socket.getsockopt(ZMQ::BACKLOG).should == value
          end

          it "should default to a value of 100" do
            value = 100
            socket.getsockopt(ZMQ::BACKLOG).should == value
          end
        end # context using option ZMQ::BACKLOG


        context "using option ZMQ::RECOVERY_IVL_MSEC" do
          it "should set the time interval for saving messages measured in milliseconds given a positive value" do
            value = 200
            socket.setsockopt ZMQ::RECOVERY_IVL_MSEC, value
            socket.getsockopt(ZMQ::RECOVERY_IVL_MSEC).should == value
          end

          it "should default to a value of -1" do
            value = -1
            socket.getsockopt(ZMQ::RECOVERY_IVL_MSEC).should == value
          end
        end # context using option ZMQ::RECOVERY_IVL_MSEC
      end # context #setsockopt


      context "#getsockopt for a #{ZMQ::SocketTypeNameMap[socket_type]} socket" do
        before(:all) { @ctx = Context.new }
        after(:all) { @ctx.terminate }

        let(:socket) do
          Socket.new @ctx.pointer, socket_type
        end

        after(:each) do
          socket.close
        end

        context "using option ZMQ::FD" do
          it "should return an FD as a positive integer" do
            socket.getsockopt(ZMQ::FD).should be_a(Fixnum)
          end

          it "should return a valid FD" do
            # Use FFI to wrap the C library function +getsockopt+ so that we can execute it
            # on the 0mq file descriptor. If it returns 0, then it succeeded and the FD
            # is valid!
            module LibSocket
              extend FFI::Library
              # figures out the correct libc for each platform including Windows
              library = ffi_lib(FFI::Library::LIBC).first
              attach_function :getsockopt, [:int, :int, :int, :pointer, :pointer], :int
            end # module LibC
            
            # these 2 hex constants were taken from OSX; may differ on other platforms
            so_rcvbuf = 0x1002
            sol_socket = 0xffff
            socklen_size = FFI::MemoryPointer.new :uint32
            socklen_size.write_int 8
            rcvbuf = FFI::MemoryPointer.new :int64
            fd = socket.getsockopt(ZMQ::FD)
            
            LibSocket.getsockopt(fd, sol_socket, so_rcvbuf, rcvbuf, socklen_size).should be_zero
          end
        end

        context "using option ZMQ::EVENTS" do
          it "should return a mask of events as a Fixnum" do
            socket.getsockopt(ZMQ::EVENTS).should be_a(Fixnum)
          end
        end
      end # context #getsockopt

    end # each socket_type


    describe "Events mapping to POLLIN and POLLOUT" do
      include APIHelper

      before(:all) do
        @ctx = Context.new
        addr = "tcp://127.0.0.1:#{random_port}"

        @sub = @ctx.socket ZMQ::SUB
        @sub.setsockopt ZMQ::SUBSCRIBE, ''

        @pub = @ctx.socket ZMQ::PUB
        @pub.connect addr

        @sub.bind addr

        @pub.send_string('test')
        sleep 0.1
      end
      after(:all) do
        @sub.close
        @pub.close
        # must call close on *every* socket before calling terminate otherwise it blocks indefinitely
        @ctx.terminate
      end

      it "should have only POLLIN set for a sub socket that received a message" do
        #@sub.getsockopt(ZMQ::EVENTS).should == ZMQ::POLLIN
      end

      it "should have only POLLOUT set for a sub socket that received a message" do
        #@pub.getsockopt(ZMQ::EVENTS).should == ZMQ::POLLOUT
      end
    end # describe 'events mapping to pollin and pollout'

  end # describe Socket


end # module ZMQ

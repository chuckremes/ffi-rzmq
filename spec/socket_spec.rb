
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Socket do

    context "when initializing" do

      let(:ctx) { Context.new 1 }

      it "should raise an error for a nil context" do
        lambda { Socket.new(FFI::Pointer::NULL, ZMQ::REQ) }.should raise_exception(ZMQ::ContextError)
      end

      it "should not raise an error for a ZMQ::REQ socket type" do
        lambda { Socket.new(ctx.pointer, ZMQ::REQ) }.should_not raise_error
      end

      it "should not raise an error for a ZMQ::REP socket type" do
        lambda { Socket.new(ctx.pointer, ZMQ::REP) }.should_not raise_error
      end

      it "should not raise an error for a ZMQ::PUB socket type" do
        lambda { Socket.new(ctx.pointer, ZMQ::PUB) }.should_not raise_error
      end

      it "should not raise an error for a ZMQ::SUB socket type" do
        lambda { Socket.new(ctx.pointer, ZMQ::SUB) }.should_not raise_error
      end

      it "should not raise an error for a ZMQ::PAIR socket type" do
        lambda { Socket.new(ctx.pointer, ZMQ::PAIR) }.should_not raise_error
      end

      it "should not raise an error for a ZMQ::XREQ socket type" do
        lambda { Socket.new(ctx.pointer, ZMQ::XREQ) }.should_not raise_error
      end

      it "should not raise an error for a ZMQ::XREP socket type" do
        lambda { Socket.new(ctx.pointer, ZMQ::XREP) }.should_not raise_error
      end

      it "should not raise an error for a ZMQ::PUSH socket type" do
        lambda { Socket.new(ctx.pointer, ZMQ::PUSH) }.should_not raise_error
      end

      it "should not raise an error for a ZMQ::PULL socket type" do
        lambda { Socket.new(ctx.pointer, ZMQ::PULL) }.should_not raise_error
      end

      it "should raise an error for an unknown socket type" do
        lambda { Socket.new(ctx.pointer, 80) }.should raise_exception(ZMQ::SocketError)
      end

      it "should set the :socket accessor to the raw socket allocated by libzmq" do
        socket = mock('socket')#.as_null_object
        socket.stub!(:null? => false)
        LibZMQ.should_receive(:zmq_socket).and_return(socket)

        sock = Socket.new(ctx.pointer, ZMQ::REQ)
        sock.socket.should == socket
      end

      it "should define a finalizer on this object" do
        pending # need to wait for 0mq 2.1 or later to fix this
        ObjectSpace.should_receive(:define_finalizer)
        ctx = Context.new 1
      end
    end # context initializing


    context "identity=" do
      it "should raise an exception for identities in excess of 255 bytes" do
        ctx = Context.new 1
        sock = Socket.new ctx.pointer, ZMQ::REQ

        lambda { sock.identity = ('a' * 256) }.should raise_exception(ZMQ::SocketError)
      end

      it "should raise an exception for identities of length 0" do
        ctx = Context.new 1
        sock = Socket.new ctx.pointer, ZMQ::REQ

        lambda { sock.identity = '' }.should raise_exception(ZMQ::SocketError)
      end

      it "should NOT raise an exception for identities of 1 byte" do
        ctx = Context.new 1
        sock = Socket.new ctx.pointer, ZMQ::REQ

        lambda { sock.identity = 'a' }.should_not raise_exception(ZMQ::SocketError)
      end

      it "should NOT raise an exception for identities of 255 bytes" do
        ctx = Context.new 1
        sock = Socket.new ctx.pointer, ZMQ::REQ

        lambda { sock.identity = ('a' * 255) }.should_not raise_exception(ZMQ::SocketError)
      end

      it "should convert numeric identities to strings" do
        ctx = Context.new 1
        sock = Socket.new ctx.pointer, ZMQ::REQ

        sock.identity = 7
        sock.identity.should == '7'
      end
    end # context identity=


    [ZMQ::REQ, ZMQ::REP, ZMQ::XREQ, ZMQ::XREP, ZMQ::PUB, ZMQ::SUB, ZMQ::PUSH, ZMQ::PULL, ZMQ::PAIR].each do |socket_type|

      context "#setsockopt for a #{ZMQ::SocketTypeNameMap[socket_type]} socket" do
        let(:socket) do
          ctx = Context.new
          Socket.new ctx.pointer, socket_type
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

            it "should raise a ZMQ::SocketError given a topic string that was never subscribed" do
              socket.setsockopt ZMQ::SUBSCRIBE, "topic.string"
              lambda { socket.setsockopt(ZMQ::UNSUBSCRIBE, "unknown") }.should raise_error(SocketError)
            end
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


#        context "using option ZMQ::SWAP" do
#          it "should set the swap value given a positive value" do
#            swap = 10_000
#            socket.setsockopt ZMQ::SWAP, swap
#            socket.getsockopt(ZMQ::SWAP).should == swap
#          end
#
#          it "should raise a SocketError given a negative value" do
#            swap = -10_000
#            lambda { socket.setsockopt(ZMQ::SWAP, swap) }.should raise_error(SocketError)
#          end
#        end # context using option ZMQ::SWP


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
        
        
#        context "using option ZMQ::RATE" do
#          it "should set the multicast send rate given a positive value" do
#            rate = 200
#            socket.setsockopt ZMQ::RATE, rate
#            socket.getsockopt(ZMQ::RATE).should == rate
#          end
#
#          it "should raise a SocketError given a negative value" do
#            rate = -200
#            lambda { socket.setsockopt ZMQ::RATE, rate }.should raise_error(SocketError)
#          end
#        end # context using option ZMQ::RATE
#        
#        
#        context "using option ZMQ::RECOVERY_IVL" do
#          it "should set the multicast recovery buffer measured in seconds given a positive value" do
#            rate = 200
#            socket.setsockopt ZMQ::RECOVERY_IVL, rate
#            socket.getsockopt(ZMQ::RECOVERY_IVL).should == rate
#          end
#
#          it "should raise a SocketError given a negative value" do
#            rate = -200
#            lambda { socket.setsockopt ZMQ::RECOVERY_IVL, rate }.should raise_error(SocketError)
#          end
#        end # context using option ZMQ::RECOVERY_IVL
        
        
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
      end # context #setsockopt

    end # each socket_type


  end # describe Socket


end # module ZMQ

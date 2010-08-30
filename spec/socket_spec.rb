
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

      it "should set the :socket accessor to non-nil" do
        sock = Socket.new(Context.new(1).pointer, ZMQ::REQ)
        sock.socket.should_not be_nil
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
    
    
  end # describe Socket


end # module ZMQ

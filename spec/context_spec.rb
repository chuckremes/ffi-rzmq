$: << "." # added for ruby 1.9.2 compatibilty; it doesn't include the current directory on the load path anymore

require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Context do

    context "when initializing" do
      include APIHelper

      it "should raise an error for negative io threads" do
        lambda { Context.new(-1) }.should raise_exception(ZMQ::ContextError)
      end

      it "should set the :pointer accessor to non-nil" do
        ctx = Context.new 1
        ctx.pointer.should_not be_nil
      end

      it "should set the :context accessor to non-nil" do
        ctx = Context.new 1
        ctx.context.should_not be_nil
      end

      it "should set the :pointer and :context accessors to the same value" do
        ctx = Context.new 1
        ctx.pointer.should == ctx.context
      end
      
      it "should define a finalizer on this object" do
        ObjectSpace.should_receive(:define_finalizer)
        ctx = Context.new 1
      end
    end # context initializing


    context "when terminating" do
      it "should call zmq_term to terminate the library's context" do
        ctx = Context.new 1
        LibZMQ.should_receive(:zmq_term).with(ctx.pointer).and_return(0)
        ctx.terminate
      end

      it "should raise an exception when it fails" do
        ctx = Context.new 1
        LibZMQ.stub(:zmq_term => 1)
        lambda { ctx.terminate }.should raise_error(ZMQ::ContextError)
      end
    end # context terminate


    context "when allocating a socket" do
      it "should return a ZMQ::Socket" do
        ctx = Context.new 1
        ctx.socket(ZMQ::REQ).should be_kind_of(ZMQ::Socket)
      end

      it "should raise an exception when allocation fails" do
        ctx = Context.new 1
        Socket.stub(:new => nil)
        lambda { ctx.socket(ZMQ::REQ) }.should raise_error(ZMQ::SocketError)
      end
    end # context socket


#    context "when allocating a device" do
#      let(:ctx) { Context.new 1 }
#      let(:sock1) { ctx.socket ZMQ::REQ }
#      let(:sock2) { ctx.socket ZMQ::REP }
#
#      it "should return a ZMQ::Forwarder" do
#        device = ctx.device ZMQ::FORWARDER, sock1, sock2
#        device.should be_kind_of(ZMQ::Forwarder)
#      end
#
#      it "should return a ZMQ::Queue" do
#        device = ctx.device ZMQ::QUEUE, sock1, sock2
#        device.should be_kind_of(ZMQ::Queue)
#      end
#
#      it "should return a ZMQ::Streamer" do
#        device = ctx.device ZMQ::STREAMER, sock1, sock2
#        device.should be_kind_of(ZMQ::Streamer)
#      end
#
#      it "should raise an exception when the requested device is unknown" do
#        lambda { ctx.device(-1, sock1, sock2) }.should raise_error(ZMQ::DeviceError)
#      end
#    end # context device


  end # describe Context


end # module ZMQ

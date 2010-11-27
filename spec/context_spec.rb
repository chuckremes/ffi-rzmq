$: << "." # added for ruby 1.9.2 compatibilty; it doesn't include the current directory on the load path anymore

require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Context do

    context "when initializing" do
      include APIHelper

      it "should raise an error for negative io threads" do
        lambda { Context.new(-1) }.should raise_exception(ZMQ::ContextError)
      end
      
      it "should default to requesting 1 i/o thread when no argument is passed" do
        ctx = mock('ctx')
        ctx.stub!(:null? => false)
        LibZMQ.should_receive(:zmq_init).with(1).and_return(ctx)
        
        Context.new
      end

      it "should set the :pointer accessor to non-nil" do
        ctx = spec_ctx
        ctx.pointer.should_not be_nil
      end

      it "should set the :context accessor to non-nil" do
        ctx = spec_ctx
        ctx.context.should_not be_nil
      end

      it "should set the :pointer and :context accessors to the same value" do
        ctx = spec_ctx
        ctx.pointer.should == ctx.context
      end
      
      it "should define a finalizer on this object" do
        ObjectSpace.should_receive(:define_finalizer)
        ctx = Context.new 1
      end
    end # context initializing


    context "when terminating" do
      it "should call zmq_term to terminate the library's context" do
        ctx = Context.new # can't use a shared context here because we are terminating it!
        LibZMQ.should_receive(:zmq_term).with(ctx.pointer).and_return(0)
        ctx.terminate
      end

      it "should raise a ZMQ::ContextError exception when it fails" do
        ctx = Context.new # can't use a shared context here because we are terminating it!
        LibZMQ.stub(:zmq_term => 1)
        lambda { ctx.terminate }.should raise_error(ZMQ::ContextError)
      end
    end # context terminate


    context "when allocating a socket" do
      it "should return a ZMQ::Socket" do
        ctx = spec_ctx
        ctx.socket(ZMQ::REQ).should be_kind_of(ZMQ::Socket)
      end

      it "should raise a ZMQ::SocketError exception when allocation fails" do
        ctx = spec_ctx
        Socket.stub(:new => nil)
        lambda { ctx.socket(ZMQ::REQ) }.should raise_error(ZMQ::SocketError)
      end
    end # context socket

  end # describe Context


end # module ZMQ

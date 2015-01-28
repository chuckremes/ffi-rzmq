$: << "." # added for ruby 1.9.2 compatibilty; it doesn't include the current directory on the load path anymore

require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Context do

    context "when initializing with factory method #create" do
      include APIHelper

      it "should return nil for negative io threads" do
        expect(Context.create(-1)).to eq(nil)
      end
      
      it "should default to requesting 1 i/o thread when no argument is passed" do
        ctx = Context.create
        expect(ctx.io_threads).to eq(1)
      end

      it "should set the :pointer accessor to non-nil" do
        ctx = Context.create
        expect(ctx.pointer).not_to be_nil
      end

      it "should set the :context accessor to non-nil" do
        ctx = Context.create
        expect(ctx.context).not_to be_nil
      end

      it "should set the :pointer and :context accessors to the same value" do
        ctx = Context.create
        expect(ctx.pointer).to eq(ctx.context)
      end
      
      it "should define a finalizer on this object" do
        expect(ObjectSpace).to receive(:define_finalizer)
        ctx = Context.create
      end
    end # context initializing


    context "when initializing with #new" do
      include APIHelper

      it "should raise a ContextError exception for negative io threads" do
        expect { Context.new(-1) }.to raise_exception(ZMQ::ContextError)
      end
      
      it "should default to requesting 1 i/o thread when no argument is passed" do
        ctx = Context.new
        expect(ctx.io_threads).to eq(1)
      end

      it "should set the :pointer accessor to non-nil" do
        ctx = Context.new
        expect(ctx.pointer).not_to be_nil
      end

      it "should set the :context accessor to non-nil" do
        ctx = Context.new
        expect(ctx.context).not_to be_nil
      end

      it "should set the :pointer and :context accessors to the same value" do
        ctx = Context.new
        expect(ctx.pointer).to eq(ctx.context)
      end
      
      it "should define a finalizer on this object" do
        expect(ObjectSpace).to receive(:define_finalizer)
        Context.new 1
      end
    end # context initializing


    context "when terminating" do
      it "should set the context to nil when terminating the library's context" do
        ctx = Context.new # can't use a shared context here because we are terminating it!
        ctx.terminate
        expect(ctx.pointer).to be_nil
      end
      
      it "should call the correct library function to terminate the context" do
        ctx = Context.new

        expect(LibZMQ).to receive(:zmq_ctx_destroy).with(ctx.pointer).and_return(0)
        ctx.terminate
      end
    end # context terminate


    context "when allocating a socket" do
      it "should return nil when allocation fails" do
        ctx = Context.new
        allow(LibZMQ).to receive(:zmq_socket).and_return(nil)
        expect(ctx.socket(ZMQ::REQ)).to be_nil
      end
    end # context socket

  end # describe Context


end # module ZMQ

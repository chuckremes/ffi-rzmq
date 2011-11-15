$: << "." # added for ruby 1.9.2 compatibilty; it doesn't include the current directory on the load path anymore

require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Poller do

    context "when initializing" do
      include APIHelper

      it "should allocate a PollItems instance" do
        PollItems.should_receive(:new)
        
        Poller.new
      end

    end # context initializing
    
    
    context "#register" do
      
      let(:poller) { Poller.new }
      let(:socket) { mock('socket') }
      
      it "should return false when given a nil socket and no file descriptor" do
        poller.register(nil, ZMQ::POLLIN, 0).should be_false
      end
      
      it "should return false when given 0 for +events+ (e.g. no registration)" do
        poller.register(socket, 0).should be_false
      end
      
      it "should return the registered event value when given a nil socket and a valid non-zero file descriptor" do
        poller.register(nil, ZMQ::POLLIN, 1).should == ZMQ::POLLIN
      end
      
      it "should return the default registered event value when given a valid socket" do
        poller.register(socket).should == (ZMQ::POLLIN | ZMQ::POLLOUT)
      end
      
      it "should access the raw 0mq socket" do
        raw_socket = FFI::MemoryPointer.new(4)
        socket.should_receive(:kind_of?).with(ZMQ::Socket).and_return(true)
        socket.should_receive(:socket).and_return(raw_socket)

        poller.register(socket)
      end
    end
    
    
    context "#delete" do
      let(:poller) { Poller.new }
      let(:socket) { mock('socket') }
      let(:context) { Context.new }
      
      it "should return false for an unregistered socket (i.e. not found)" do
        poller.delete(socket).should be_false
      end
      
      it "returns true for a sucessfully deleted socket when only 1 is registered" do
        socket1 = context.socket ZMQ::REP

        poller.register socket1
        poller.delete(socket1).should be_true
      end
      
      it "returns true for a sucessfully deleted socket when more than 1 is registered" do
        socket1 = context.socket ZMQ::REP
        socket2 = context.socket ZMQ::REP

        poller.register socket1
        poller.register socket2
        poller.delete(socket2).should be_true
      end
      
    end


  end # describe Poll


end # module ZMQ

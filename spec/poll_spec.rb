$: << "." # added for ruby 1.9.2 compatibilty; it doesn't include the current directory on the load path anymore

require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Context do

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
        raw_socket = mock('raw socket')
        socket.should_receive(:kind_of?).with(ZMQ::Socket).and_return(true)
        socket.should_receive(:socket).and_return(raw_socket)
        raw_socket.should_receive(:address)
        poller.register(socket)
      end
    end
    
    
    context "#delete" do
      let(:poller) { Poller.new }
      let(:socket) { mock('socket') }
      
      it "should return false for an unregistered socket (i.e. not found)" do
        address = mock('address')
        raw_socket = mock('raw_socket')
        socket.should_receive(:socket).at_least(1).and_return(raw_socket)
        raw_socket.should_receive(:address).at_least(1).and_return(address)
        
        poller.delete(socket).should be_false
      end
      
      it "should return true for a sucessfully deleted socket" do
        rawsocket = FFI::MemoryPointer.new(4)
        socket.stub(:kind_of? => true, :socket => rawsocket)

        poller.register socket
        poller.delete(socket).should be_true
      end
    end


  end # describe Poll


end # module ZMQ

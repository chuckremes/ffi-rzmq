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
      before(:all) do
        @context = Context.new
      end
      
      before(:each) do
        @socket = @context.socket(XREQ)
        @socket.setsockopt(LINGER, 0)
        @poller = Poller.new
      end
      
      after(:each) do
        @socket.close
      end
      
      after(:all) do
        @context.terminate
      end
      
      it "should return false for an unregistered socket (i.e. not found)" do
        @poller.delete(@socket).should be_false
      end
      
      it "returns true for a sucessfully deleted socket when only 1 is registered" do
        socket1 = @context.socket(REP)
        socket1.setsockopt(LINGER, 0)

        @poller.register socket1
        @poller.delete(socket1).should be_true
        socket1.close
      end
      
      it "returns true for a sucessfully deleted socket when more than 1 is registered" do
        socket1 = @context.socket(REP)
        socket2 = @context.socket(REP)
        socket1.setsockopt(LINGER, 0)
        socket2.setsockopt(LINGER, 0)

        @poller.register socket1
        @poller.register socket2
        @poller.delete(socket2).should be_true
        socket1.close
        socket2.close
      end
      
    end
    
    
    context "poll" do
      include APIHelper
      
      before(:all) do
      end
      
      before(:each) do
        # Must recreate context for each test otherwise some poll tests fail.
        # This is likely due to a race condition in event handling when reusing
        # the same inproc inside the same context over and over. Making a new
        # context solves it.
        @context = Context.new
        endpoint = "inproc://poll_test"
        @socket = @context.socket(DEALER)
        @socket2 = @context.socket(ROUTER)
        @socket.setsockopt(LINGER, 0)
        @socket2.setsockopt(LINGER, 0)
        @socket.bind(endpoint)
        connect_to_inproc(@socket2, endpoint)

        @poller = Poller.new
      end
      
      after(:each) do
        @socket.close
        @socket2.close
        @context.terminate
      end
      
      it "returns 0 when there are no sockets to poll" do
        rc = @poller.poll(100)
        rc.should be_zero
      end
      
      it "returns 0 when there is a single socket to poll and no events" do
        @poller.register(@socket, 0)
        rc = @poller.poll(100)
        rc.should be_zero
      end
      
      it "returns 1 when there is a read event on a socket" do
        @poller.register_readable(@socket2)
        
        @socket.send_string('test')
        rc = @poller.poll(1000)
        rc.should == 1
      end
      
      it "returns 1 when there is a read event on one socket and the second socket has been removed from polling" do
        @poller.register_readable(@socket2)
        @poller.register_writable(@socket)
        
        @socket.send_string('test')
        @poller.deregister_writable(@socket)

        rc = @poller.poll(1000)
        rc.should == 1
      end
    end # poll


  end # describe Poll


end # module ZMQ

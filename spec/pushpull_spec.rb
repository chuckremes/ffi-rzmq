
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ
  describe Socket do
    context "when running basic push pull" do
      include APIHelper

      let(:string) { "booga-booga" }
      
      before(:each) do
        # Use new context for each iteration to avoid inproc race. See
        # poll_spec.rb for more details.
        @context = Context.new
        poller_setup

        @push = @context.socket ZMQ::PUSH
        @pull = @context.socket ZMQ::PULL
        @push.setsockopt ZMQ::LINGER, 0
        @pull.setsockopt ZMQ::LINGER, 0
        
        @link = "inproc://push_pull_test"
        @push.bind @link
        connect_to_inproc(@pull, @link)
      end

      after(:each) do
        @push.close
        @pull.close
        @context.terminate
      end

      it "should receive an exact copy of the sent message using Message objects directly on one pull socket" do
        @push.send_string string
        received = ''
        rc = @pull.recv_string received
        assert_ok(rc)
        received.should == string
      end

      it "should receive an exact string copy of the message sent when receiving in non-blocking mode and using Message objects directly" do
        sent_message = Message.new string
        received_message = Message.new

        poll_it_for_read(@pull) do
          rc = @push.sendmsg sent_message
          LibZMQ.version2? ? rc.should == 0 : rc.should == string.size
        end
        
        rc = @pull.recvmsg received_message, ZMQ::NonBlocking
        LibZMQ.version2? ? rc.should == 0 : rc.should == string.size
        received_message.copy_out_string.should == string
      end



      it "should receive a single message for each message sent on each socket listening, when an equal number of sockets pulls messages and where each socket is unique per thread" do
        received = []
        threads  = []
        sockets = []
        count    = 4
        mutex = Mutex.new
        
        # make sure all sockets are connected before we do our load-balancing test
        (count - 1).times do
          socket = @context.socket ZMQ::PULL
          socket.setsockopt ZMQ::LINGER, 0
          connect_to_inproc(socket, @link)
          sockets << socket
        end
        sockets << @pull

        sockets.each do |socket|
          threads << Thread.new do
            buffer = ''
            rc = socket.recv_string buffer
            version2? ? (rc.should == 0) : (rc.should == buffer.size)
            mutex.synchronize { received << buffer }
            socket.close
          end
        end

        count.times { @push.send_string(string) }

        threads.each {|t| t.join}

        received.find_all {|r| r == string}.length.should == count
      end

      it "should receive a single message for each message sent when using a single shared socket protected by a mutex" do
        received = []
        threads  = []
        count    = 4
        mutex = Mutex.new

        count.times do |i|
          threads << Thread.new do
            buffer = ''
            rc = 0
            mutex.synchronize { rc = @pull.recv_string buffer }
            version2? ? (rc.should == 0) : (rc.should == buffer.size)
            mutex.synchronize { received << buffer }
          end
        end

        count.times { @push.send_string(string) }

        threads.each {|t| t.join}

        received.find_all {|r| r == string}.length.should == count
      end

    end # @context ping-pong
  end # describe
end # module ZMQ

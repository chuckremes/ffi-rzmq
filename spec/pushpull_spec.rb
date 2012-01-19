
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ
  describe Context do
    context "when running basic push pull" do
      include APIHelper

      let(:string) { "booga-booga" }

      before(:each) do
        $stdout.flush
        @context = ZMQ::Context.new
        @push = @context.socket ZMQ::PUSH
        @pull = @context.socket ZMQ::PULL
        @push.setsockopt ZMQ::LINGER, 0
        @pull.setsockopt ZMQ::LINGER, 0
        port = connect_to_random_tcp_port(@pull)
        @link = "tcp://127.0.0.1:#{port}"
        #@link = "inproc://push_pull_test" # can't connect to inproc *before* bind
        @push.bind    @link
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

        rc = @push.sendmsg sent_message
        LibZMQ.version2? ? rc.should == 0 : rc.should == string.size
        sleep 0.1 # give it time for delivery
        rc = @pull.recvmsg received_message, ZMQ::NonBlocking
        LibZMQ.version2? ? rc.should == 0 : rc.should == string.size
        received_message.copy_out_string.should == string
      end



      it "should receive a single message for each message sent on each socket listening, when an equal number pulls to messages and a unique socket per thread" do
        received = []
        threads  = []
        count    = 4
        @pull.close # close this one since we aren't going to use it below and we don't want it to receive a message
        mutex = Mutex.new

        count.times do |i|
          threads << Thread.new do
            pull = @context.socket ZMQ::PULL
            rc = pull.setsockopt ZMQ::LINGER, 0
            rc = pull.connect @link
            rc.should == 0
            buffer = ''
            rc = pull.recv_string buffer
            rc.should == 0
            mutex.synchronize { received << buffer }
            pull.close
          end
          sleep 0.01 # give each thread time to spin up
        end

        count.times { @push.send_string(string) }

        threads.each {|t| t.join}

        received.find_all {|r| r == string}.length.should == count
      end

      it "should receive a single message for each message sent on each socket listening, when an equal number pulls to messages and a single shared socket protected by a mutex" do
        received = []
        threads  = []
        count    = 4
        @pull.close # close this one since we aren't going to use it below and we don't want it to receive a message
        pull = @context.socket ZMQ::PULL
        rc = pull.setsockopt ZMQ::LINGER, 0
        rc = pull.connect @link
        rc.should == 0
        mutex = Mutex.new

        count.times do |i|
          threads << Thread.new do
            buffer = ''
            rc = 0
            mutex.synchronize { rc = pull.recv_string buffer }
            rc.should == 0
            mutex.synchronize { received << buffer }
          end
          sleep 0.01 # give each thread time to spin up
        end

        count.times { @push.send_string(string) }

        threads.each {|t| t.join}
        pull.close

        received.find_all {|r| r == string}.length.should == count
      end

    end # @context ping-pong
  end # describe
end # module ZMQ

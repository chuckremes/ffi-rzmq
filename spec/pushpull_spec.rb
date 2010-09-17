
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ
  describe Context do
    context "when running basic push pull" do
      include APIHelper

      let(:string) { "booga-booga" }

      before(:each) do
        $stdout.flush
        @context = ZMQ::Context.new 1
        @push = @context.socket ZMQ::PUSH
        @pull = @context.socket ZMQ::PULL
        @link = "tcp://127.0.0.1:#{random_port}"
        @pull.connect @link
        @push.bind    @link
      end

      it "should receive an exact copy of the sent message using Message objects directly on one pull socket" do
        @push.send_string string
        received = @pull.recv_string
        received.should == string
      end
       
      it "should receive an exact string copy of the message sent when receiving in non-blocking mode and using Message objects directly" do
        sent_message = Message.new string
        received_message = Message.new

        @push.send sent_message
        sleep 0.1 # give it time for delivery
        @pull.recv received_message, ZMQ::NOBLOCK
        received_message.copy_out_string.should == string
      end

      it "should receive an exact string copy of the message sent when sending in non-blocking mode and using Message objects directly" do
        sent_message = Message.new string
        received_message = Message.new

        @push.send sent_message, ZMQ::NOBLOCK
        sleep 0.1 # give it time for delivery
        @pull.recv received_message, ZMQ::NOBLOCK
        received_message.copy_out_string.should == string
      end

      it "should receive a single message for each message sent on each socket listening, when an equal number pulls to messages" do
        received = []
        threads  = []
        count    = 4
         
        count.times {
          threads << Thread.new {
            pull = @context.socket ZMQ::PULL
            pull.connect @link
            received << pull.recv_string
            pull.close
          }
        }
        
        count.times { @push.send_string(string); sleep 0.001 }
        
        threads.each {|t| t.join}
        
        received.find_all {|r| r == string}.length.should == count
      end
      
    end # @context ping-pong
  end # describe
end # module ZMQ

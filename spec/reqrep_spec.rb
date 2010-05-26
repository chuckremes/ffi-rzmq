
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Context do

    context "when running ping pong" do
      include APIHelper

      let(:string) { "booga-booga" }

      before(:each) do
        context = ZMQ::Context.new 1, 1
        @ping = context.socket ZMQ::REQ
        @pong = context.socket ZMQ::REP
        link = "tcp://127.0.0.1:#{random_port}"
        @pong.bind link
        @ping.connect link
      end

      it "should receive an exact string copy of the string message sent" do
        @ping.send_string string
        received_message = @pong.recv_string

        received_message.should == string
      end

      it "should receive an exact copy of the sent message using Message objects directly" do
        sent_message = Message.new string
        received_message = Message.new

        @ping.send sent_message
        @pong.recv received_message

        received_message.copy_out_string.should == string
      end

      it "should receive an exact copy of the sent message using Message objects directly in non-blocking mode" do
        sent_message = Message.new string
        received_message = Message.new

        @ping.send sent_message, ZMQ::NOBLOCK
        sleep 0.001 # give it time for delivery
        @pong.recv received_message, ZMQ::NOBLOCK

        received_message.copy_out_string.should == string
      end
    end # context ping-pong


  end # describe


end # module ZMQ

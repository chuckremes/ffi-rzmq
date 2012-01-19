
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Context do

    context "when running ping pong" do
      include APIHelper

      let(:string) { "booga-booga" }

      before(:each) do
        context = ZMQ::Context.new 1
        @ping = context.socket ZMQ::REQ
        @pong = context.socket ZMQ::REP
        port = bind_to_random_tcp_port(@pong)
        @ping.connect "tcp://127.0.0.1:#{port}"
      end

      after(:each) do
        @ping.close
        @pong.close
      end

      it "should receive an exact string copy of the string message sent" do
        @ping.send_string string
        received_message = ''
        rc = @pong.recv_string received_message

        received_message.should == string
      end

      it "should receive an exact copy of the sent message using Message objects directly" do
        sent_message = Message.new string
        received_message = Message.new

        rc = @ping.sendmsg sent_message
        LibZMQ.version2? ? rc.should == 0 : rc.should == string.size
        rc = @pong.recvmsg received_message
        LibZMQ.version2? ? rc.should == 0 : rc.should == string.size

        received_message.copy_out_string.should == string
      end

      it "should receive an exact copy of the sent message using Message objects directly in non-blocking mode" do
        sent_message = Message.new string
        received_message = Message.new

        rc = @ping.sendmsg sent_message, ZMQ::NonBlocking
        LibZMQ.version2? ? rc.should == 0 : rc.should == string.size
        sleep 0.001 # give it time for delivery
        rc = @pong.recvmsg received_message, ZMQ::NonBlocking
        LibZMQ.version2? ? rc.should == 0 : rc.should == string.size

        received_message.copy_out_string.should == string
      end

    end # context ping-pong


  end # describe


end # module ZMQ

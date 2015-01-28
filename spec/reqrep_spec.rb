
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Socket do

    context "when running ping pong" do
      include APIHelper

      let(:string) { "booga-booga" }

      # reset sockets each time because we only send 1 message which leaves
      # the REQ socket in a bad state. It cannot send again unless we were to
      # send a reply with the REP and read it.
      before(:each) do
        @context = ZMQ::Context.new
        poller_setup

        endpoint = "inproc://reqrep_test"
        @ping = @context.socket ZMQ::REQ
        @pong = @context.socket ZMQ::REP
        @pong.bind(endpoint)
        connect_to_inproc(@ping, endpoint)
      end

      after(:each) do
        @ping.close
        @pong.close
        @context.terminate
      end
      
      def send_ping(string)
        @ping.send_string string
        received_message = ''
        rc = @pong.recv_string received_message
        [rc, received_message]
      end

      it "should receive an exact string copy of the string message sent" do
        rc, received_message = send_ping(string)
        expect(received_message).to eq(string)
      end
      
      it "should generate a EFSM error when sending via the REQ socket twice in a row without an intervening receive operation" do
        send_ping(string)
        rc = @ping.send_string(string)
        expect(rc).to eq(-1)
        expect(Util.errno).to eq(ZMQ::EFSM)
      end

      it "should receive an exact copy of the sent message using Message objects directly" do
        received_message = Message.new

        rc = @ping.sendmsg(Message.new(string))
        expect(rc).to eq(string.size)
        rc = @pong.recvmsg received_message
        expect(rc).to eq(string.size)

        expect(received_message.copy_out_string).to eq(string)
      end

      it "should receive an exact copy of the sent message using Message objects directly in non-blocking mode" do
        sent_message = Message.new string
        received_message = Message.new

        poll_it_for_read(@pong) do
          rc = @ping.sendmsg(Message.new(string), ZMQ::DONTWAIT)
          expect(rc).to eq(string.size)
        end
        
        rc = @pong.recvmsg received_message, ZMQ::DONTWAIT
        expect(rc).to eq(string.size)

        expect(received_message.copy_out_string).to eq(string)
      end

    end # context ping-pong


  end # describe


end # module ZMQ

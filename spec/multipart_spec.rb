require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ
  describe Socket do
    context "multipart messages" do
      before(:all) { @ctx = Context.new }
      after(:all) { @ctx.terminate }

      context "without identity" do
        include APIHelper

        before(:all) do
          addr = "tcp://127.0.0.1:#{random_port}"

          @rep = Socket.new(@ctx.pointer, ZMQ::REP)
          @rep.bind(addr)

          @req = Socket.new(@ctx.pointer, ZMQ::REQ)
          @req.connect(addr)
        end

        after(:all) do
          @req.close
          @rep.close
        end

        it "should be delivered between REQ and REP returning an array of strings" do
          req_data, rep_data = [ "1", "2" ], [ "2", "3" ]

          @req.send_strings(req_data)
          @rep.recv_strings.should == req_data

          @rep.send_strings(rep_data)
          @req.recv_strings.should == rep_data
        end

        it "should be delivered between REQ and REP returning an array of messages" do
          req_data, rep_data = [ "1", "2" ], [ "2", "3" ]

          @req.send_strings(req_data)
          @rep.recvmsgs.each_with_index do |message, index|
            message.copy_out_string.should == req_data[index]
          end

          @rep.send_strings(rep_data)
          @req.recvmsgs.each_with_index do |message, index|
            message.copy_out_string.should == rep_data[index]
          end
        end
      end

      context "with identity" do
        include APIHelper

        before(:all) do
          addr = "tcp://127.0.0.1:#{random_port}"

          @rep = Socket.new(@ctx.pointer, ZMQ::XREP)
          @rep.bind(addr)

          @req = Socket.new(@ctx.pointer, ZMQ::REQ)
          @req.identity = 'foo'
          @req.connect(addr)
        end

        after(:all) do
          @req.close
          @rep.close
        end

        it "should be delivered between XREP and REQ returning an array of strings" do
          req_data, rep_data = "hello", [ @req.identity, "", "ok" ]

          @req.send_string(req_data)
          @rep.recv_strings.should == [ @req.identity, "", "hello" ]

          @rep.send_strings(rep_data)
          @req.recv_string.should == rep_data.last
        end

        it "should be delivered between XREP and REQ returning an array of messages" do
          req_data, rep_data = "hello", [ @req.identity, "", "ok" ]

          @req.send_string(req_data)
          msgs = @rep.recvmsgs
          msgs[0].copy_out_string.should == @req.identity
          msgs[1].copy_out_string.should == ""
          msgs[2].copy_out_string.should == "hello"

          @rep.send_strings(rep_data)
          msgs = @req.recvmsgs
          msgs[0].copy_out_string.should == rep_data.last
        end
      end
    end
  end
end

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

        it "should be delivered between REQ and REP" do
          req_data, rep_data = [ "1", "2" ], [ "2", "3" ]

          @req.send_multipart(req_data)
          @rep.recv_multipart.should == req_data

          @rep.send_multipart(rep_data)
          @req.recv_multipart.should == rep_data
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

        it "should be delivered between XREP and REQ" do
          req_data, rep_data = "hello", [ @req.identity, "", "ok" ]

          @req.send_string(req_data)
          @rep.recv_multipart.should == [ @req.identity, "", "hello" ]

          @rep.send_multipart(rep_data)
          @req.recv_string.should == rep_data.last
        end
      end
    end
  end
end

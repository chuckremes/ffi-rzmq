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
          strings = []
          rc = @rep.recv_strings(strings)
          strings.should == req_data

          @rep.send_strings(rep_data)
          strings = []
          rc = @req.recv_strings(strings)
          strings.should == rep_data
        end

        it "should be delivered between REQ and REP returning an array of messages" do
          req_data, rep_data = [ "1", "2" ], [ "2", "3" ]

          @req.send_strings(req_data)
          messages = []
          rc = @rep.recvmsgs(messages)
          messages.each_with_index do |message, index|
            message.copy_out_string.should == req_data[index]
          end

          @rep.send_strings(rep_data)
          messages = []
          rc = @req.recvmsgs(messages)
          messages.each_with_index do |message, index|
            message.copy_out_string.should == rep_data[index]
          end
        end
      end

      if version2?
        context "with identity" do
          include APIHelper

          before(:each) do # was :all
            addr = "tcp://127.0.0.1:#{random_port}"

            @rep = Socket.new(@ctx.pointer, ZMQ::XREP)
            @rep.bind(addr)

            @req = Socket.new(@ctx.pointer, ZMQ::REQ)
            @req.identity = 'foo'
            @req.connect(addr)
          end

          after(:each) do # was :all
            @req.close
            @rep.close
          end

          it "should be delivered between REQ and REP returning an array of strings with an empty string as the envelope delimiter" do
            req_data, rep_data = "hello", [ @req.identity, "", "ok" ]

            @req.send_string(req_data)
            strings = []
            rc = @rep.recv_strings(strings)
            strings.should == [ @req.identity, "", "hello" ]

            @rep.send_strings(rep_data)
            string = ''
            rc = @req.recv_string(string)
            string.should == rep_data.last
          end

          it "should be delivered between REQ and REP returning an array of messages with an empty string as the envelope delimiter" do
            req_data, rep_data = "hello", [ @req.identity, "", "ok" ]

            @req.send_string(req_data)
            msgs = []
            rc = @rep.recvmsgs(msgs)
            msgs[0].copy_out_string.should == @req.identity
            msgs[1].copy_out_string.should == ""
            msgs[2].copy_out_string.should == "hello"

            @rep.send_strings(rep_data)
            msgs = []
            rc = @req.recvmsgs(msgs)
            msgs[0].copy_out_string.should == rep_data.last
          end
        end

      else # version3 or 4

        context "with identity" do
          include APIHelper

          before(:each) do # was :all
            addr = "tcp://127.0.0.1:#{random_port}"

            @rep = Socket.new(@ctx.pointer, ZMQ::ROUTER)
            @rep.bind(addr)

            @req = Socket.new(@ctx.pointer, ZMQ::DEALER)
            @req.identity = 'foo'
            @req.connect(addr)
          end

          after(:each) do # was :all
            @req.close
            @rep.close
          end

          it "should be delivered between ROUTER and DEALER returning an array of strings" do
            req_data, rep_data = "hello", [ @req.identity, "ok" ]

            @req.send_string(req_data)
            strings = []
            rc = @rep.recv_strings(strings)
            strings.should == [ @req.identity, "hello" ]

            @rep.send_strings(rep_data)
            string = ''
            rc = @req.recv_string(string)
            string.should == rep_data.last
          end

          it "should be delivered between ROUTER and DEALER returning an array of messages" do
            req_data, rep_data = "hello", [ @req.identity, "ok" ]

            @req.send_string(req_data)
            msgs = []
            rc = @rep.recvmsgs(msgs)
            msgs[0].copy_out_string.should == @req.identity
            msgs[1].copy_out_string.should == "hello"

            @rep.send_strings(rep_data)
            msgs = []
            rc = @req.recvmsgs(msgs)
            msgs[0].copy_out_string.should == rep_data.last
          end

        end

      end # if version...


    end
  end
end

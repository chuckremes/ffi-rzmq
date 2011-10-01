
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Socket do

    describe "non-blocking #recvmsgs" do
      include APIHelper

      before(:all) do
        @ctx = Context.new
        addr = "tcp://127.0.0.1:#{random_port}"

        @sub = @ctx.socket ZMQ::SUB
        @sub.setsockopt ZMQ::SUBSCRIBE, ''
        @sub.bind addr
        @pub = @ctx.socket ZMQ::PUB
        @pub.connect addr
        sleep 0.2
      end

      after(:all) do
        @sub.close
        @pub.close
        # must call close on *every* socket before calling terminate otherwise it blocks indefinitely
        @ctx.terminate
      end

      NonBlockingFlag = LibZMQ.version2? ? NOBLOCK : DONTWAIT

        it "reads all message parts transmitted and returns a successful result code" do
          strings = Array.new(10, 'test')
          rc = @pub.send_strings(strings)
          rc.should == 0
          sleep 0.1 # give it time to deliver to the sub socket

          array = []
          rc = @sub.recvmsgs(array, NonBlockingFlag)
          rc.should == 0
          array.size.should == 10
          @sub.recvmsgs(array, NonBlockingFlag).should == -1
        end

        it "returns -1 and gets EAGAIN when there are no messages to read" do
          array = []
          rc = @sub.recvmsgs(array, NonBlockingFlag)
          rc.should == -1
          array.size.should == 0
          ZMQ::Util.errno.should == ZMQ::EAGAIN
        end

    end # describe 'non-blocking recvmsgs'

  end # describe Socket


end # module ZMQ

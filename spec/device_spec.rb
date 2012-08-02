
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ
  describe Device do
    include APIHelper

    before(:all) do
      @ctx = Context.new
    end

    after(:all) do
      @ctx.terminate
    end

    def create_streamer
      @backport = @frontport = nil
      Thread.new do
        back  = @ctx.socket(ZMQ::PULL)
        @backport = bind_to_random_tcp_port(back)
        front = @ctx.socket(ZMQ::PUSH)
        @frontport = bind_to_random_tcp_port(front)
        Device.new(ZMQ::STREAMER, back, front)
        back.close
        front.close
      end
      thread_startup_sleep
    end

    it "should create a device without error given valid opts" do
      create_streamer
    end

    it "should be able to send messages through the device" do
      create_streamer

      pusher = @ctx.socket(ZMQ::PUSH)
      pusher.connect("tcp://127.0.0.1:#{@backport}")
      puller = @ctx.socket(ZMQ::PULL)
      puller.connect("tcp://127.0.0.1:#{@frontport}")

      pusher.send_string("hello")
      delivery_sleep
      res = ''
      rc = puller.recv_string(res, ZMQ::NonBlocking)
      res.should == "hello"

      pusher.close
      puller.close
    end

    it "should raise an ArgumentError when trying to pass non-socket objects into the device" do
      lambda {
        Device.new(ZMQ::STREAMER, 1,2)
      }.should raise_exception(ArgumentError)
    end
  end
end

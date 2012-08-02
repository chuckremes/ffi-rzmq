
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ
  describe Device do
    include APIHelper

    before(:all) do
      @ctx = Context.new
      poller_setup
      @front_endpoint = "inproc://device_front_test"
      @back_endpoint = "inproc://device_back_test"
      @mutex = Mutex.new
    end

    after(:all) do
      @ctx.terminate
    end

    def create_streamer
      @device_thread = false

      Thread.new do
        back  = @ctx.socket(ZMQ::PULL)
        back.bind(@back_endpoint)
        front = @ctx.socket(ZMQ::PUSH)
        front.bind(@front_endpoint)
        @mutex.synchronize { @device_thread = true }
        Device.new(ZMQ::STREAMER, back, front)
        back.close
        front.close
      end
    end
    
    def wait_for_device
      loop do
        can_break = false
        @mutex.synchronize do
          can_break = true if @device_thread
        end
        break if can_break
      end
    end

    it "should create a device without error given valid opts" do
      create_streamer
      wait_for_device
    end

    it "should be able to send messages through the device" do
      create_streamer
      wait_for_device

      pusher = @ctx.socket(ZMQ::PUSH)
      connect_to_inproc(pusher, @back_endpoint)
      puller = @ctx.socket(ZMQ::PULL)
      connect_to_inproc(puller, @front_endpoint)

      poll_it_for_read(puller) do
        pusher.send_string("hello")
      end

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

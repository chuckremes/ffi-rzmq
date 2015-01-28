
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ
  describe Device do
    include APIHelper

    before(:each) do
      @ctx = Context.new
      poller_setup
      @front_endpoint = "inproc://device_front_test"
      @back_endpoint = "inproc://device_back_test"
      @mutex = Mutex.new
    end

    after(:each) do
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
        puts "create streamer device and running..."
        Device.new(back, front)
        puts "device exited"
        back.close
        front.close
      end
    end
    
    def wait_for_device
      loop do
        can_break = @mutex.synchronize { @device_thread }
        
        break if can_break
      end
      puts "broke out of wait_for_device loop"
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
      rc = puller.recv_string(res, ZMQ::DONTWAIT)
      expect(res).to eq("hello")

      pusher.close
      puller.close
    end

    it "should raise an ArgumentError when trying to pass non-socket objects into the device" do
      expect {
        Device.new(1,2)
      }.to raise_exception(ArgumentError)
    end
  end
end

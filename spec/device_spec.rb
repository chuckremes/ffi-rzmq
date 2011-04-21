
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ
  describe Device do
    include APIHelper
    
    def create_streamer
      @back_addr  = "tcp://127.0.0.1:#{random_port}"
      @front_addr = "tcp://127.0.0.1:#{random_port}"
      Thread.new do
        back  = SPEC_CTX.socket(ZMQ::PULL)
        back.bind(@back_addr)
        front = SPEC_CTX.socket(ZMQ::PUSH)
        front.bind(@front_addr)
        Device.new(ZMQ::STREAMER, back, front)
      end
    end
    
    it "should create a streamer device without error given valid opts" do
      create_streamer
    end

    it "should be able to send messages through the device" do
      create_streamer
      
      pusher = SPEC_CTX.socket(ZMQ::PUSH)
      pusher.connect(@back_addr)
      puller = SPEC_CTX.socket(ZMQ::PULL)
      puller.connect(@front_addr)
      
      pusher.send_string("hello")
      sleep 0.5
      res = puller.recv_string(ZMQ::NOBLOCK)
      res.should == "hello"
    end

    it "should raise an ArgumentError when trying to pass non-socket objects into the device" do
      lambda {
        Device.new(ZMQ::STREAMER, 1,2)
      }.should raise_exception(ArgumentError)
    end

    it "should be able to create a forwarder device without error" do
      back_addr  = "tcp://127.0.0.1:#{random_port}"
      front_addr = "tcp://127.0.0.1:#{random_port}"
      Thread.new do
        back  = SPEC_CTX.socket(ZMQ::SUB)
        back.bind(back_addr)
        front = SPEC_CTX.socket(ZMQ::PUB)
        front.bind(front_addr)
        Device.new(ZMQ::FORWARDER, back, front)
      end
    end
     
    it "should be able to create a queue device without error" do
      back_addr  = "tcp://127.0.0.1:#{random_port}"
      front_addr = "tcp://127.0.0.1:#{random_port}"
      Thread.new do
        back  = SPEC_CTX.socket(ZMQ::ROUTER)
        back.bind(back_addr)
        front = SPEC_CTX.socket(ZMQ::DEALER)
        front.bind(front_addr)
        Device.new(ZMQ::QUEUE, back, front)
      end
    end
  end
end

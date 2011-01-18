
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Message do

    context "when initializing with an argument" do
      
      it "should *not* define a finalizer on this object" do
        ObjectSpace.should_not_receive(:define_finalizer)
        Message.new "text"
      end
    end # context initializing


    context "when copying in data" do
      it "should raise a MessageError when the Message is being reused" do
        message = Message.new "text"
        lambda { message.copy_in_string("new text") }.should raise_error(MessageError)
      end
    end
    
    context "when copying binary data" do
      it "should find the correct length by ignoring encoding" do
        message = Message.new
        message.copy_in_string("\x83\x6e\x04\x00\x00\x44\xd1\x81")
        message.size.should_equal(8)
      end
    end

  end # describe Message
  
  
  describe ManagedMessage do

    context "when initializing with an argument" do
      
      it "should define a finalizer on this object" do
        ObjectSpace.should_receive(:define_finalizer)
        ManagedMessage.new "text"
      end
    end # context initializing


  end # describe ManagedMessage


end # module ZMQ

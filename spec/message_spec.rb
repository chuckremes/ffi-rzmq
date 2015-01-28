
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Message do

    context "when initializing with an argument" do

      it "calls zmq_msg_init_data()" do
        expect(LibZMQ).to receive(:zmq_msg_init_data)
        message = Message.new "text"
      end

      it "should *not* define a finalizer on this object" do
        expect(ObjectSpace).not_to receive(:define_finalizer)
        Message.new "text"
      end
    end # context initializing with arg

    context "when initializing *without* an argument" do

      it "calls zmq_msg_init()" do
        expect(LibZMQ).to receive(:zmq_msg_init).and_return(0)
        message = Message.new
      end

      it "should *not* define a finalizer on this object" do
        expect(ObjectSpace).not_to receive(:define_finalizer)
        Message.new "text"
      end
    end # context initializing with arg


    context "#copy_in_string" do
      it "calls zmq_msg_init_data()" do
        message = Message.new "text"

        expect(LibZMQ).to receive(:zmq_msg_init_data)
        message.copy_in_string("new text")
      end

      it "correctly finds the length of binary data by ignoring encoding" do
        message = Message.new
        message.copy_in_string("\x83\x6e\x04\x00\x00\x44\xd1\x81")
        expect(message.size).to eq(8)
      end
    end


    context "#copy" do
      it "calls zmq_msg_copy()" do
        message = Message.new "text"
        copy = Message.new

        expect(LibZMQ).to receive(:zmq_msg_copy)
        copy.copy(message)
      end
    end # context copy


    context "#move" do
      it "calls zmq_msg_move()" do
        message = Message.new "text"
        copy = Message.new

        expect(LibZMQ).to receive(:zmq_msg_move)
        copy.move(message)
      end
    end # context move


    context "#size" do
      it "calls zmq_msg_size()" do
        message = Message.new "text"

        expect(LibZMQ).to receive(:zmq_msg_size)
        message.size
      end
    end # context size


    context "#data" do
      it "calls zmq_msg_data()" do
        message = Message.new "text"

        expect(LibZMQ).to receive(:zmq_msg_data)
        message.data
      end
    end # context data


    context "#close" do
      it "calls zmq_msg_close() the first time" do
        message = Message.new "text"

        expect(LibZMQ).to receive(:zmq_msg_close)
        message.close
      end

      it "*does not* call zmq_msg_close() on subsequent invocations" do
        message = Message.new "text"
        message.close

        expect(LibZMQ).not_to receive(:zmq_msg_close)
        message.close
      end
    end # context close

  end # describe Message


  describe ManagedMessage do

    context "when initializing with an argument" do

      it "should define a finalizer on this object" do
        expect(ObjectSpace).to receive(:define_finalizer)
        ManagedMessage.new "text"
      end
    end # context initializing


  end # describe ManagedMessage


end # module ZMQ

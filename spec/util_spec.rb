require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ
  describe Util do

    if LibZMQ.version4?
      describe "curve_keypair" do

        it "returns a set of public and private keys" do
          public_key, private_key = ZMQ::Util.curve_keypair

          public_key.should_not == private_key
          public_key.should_not be_nil
          private_key.should_not be_nil
        end

        it "raises if zmq does not support CURVE (libsodium not linked)" do
          lambda {
            LibZMQ.should_receive(:zmq_curve_keypair).and_return(-1)
            ZMQ::Util.curve_keypair
          }.should raise_exception(ZMQ::NotSupportedError)
        end

      end
    end

  end
end

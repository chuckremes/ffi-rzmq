require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ
  describe Util do

    if LibZMQ.version4?
      describe "curve_keypair" do

        it "returns a set of public and private keys (libsodium linked)" do
          expect(ZMQ::Util).to receive(:curve_keypair).and_return([0, 1])
          public_key, private_key = ZMQ::Util.curve_keypair

          expect(public_key).not_to eq private_key
          expect(public_key).not_to be_nil
          expect(private_key).not_to be_nil
        end

        it "raises if zmq does not support CURVE (libsodium not linked)" do
          expect do
            allow(LibZMQ).to receive(:zmq_curve_keypair).and_return(-1)
            ZMQ::Util.curve_keypair
          end.to raise_exception(ZMQ::NotSupportedError)
        end

      end
    end

  end
end

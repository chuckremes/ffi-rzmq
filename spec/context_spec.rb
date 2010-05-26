
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


    describe Context do

      context "when initializing" do
        include APIHelper
        
        before(:all) do
          #stub_libzmq
        end
        
        it "should raise an error for negative app threads" do
          lambda { Context.new -1, -1, 0 }.should raise_exception(ZMQ::ContextError)
        end
        
        it "should not raise an error for positive thread counts" do
          lambda { Context.new 1, 1, 0 }.should_not raise_error
        end
      end # context initializing
    end

    
end # module ZMQ

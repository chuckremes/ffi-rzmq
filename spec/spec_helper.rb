
require File.expand_path(
    File.join(File.dirname(__FILE__), %w[.. lib ffi-rzmq]))

Spec::Runner.configure do |config|
  # == Mock Framework
  #
  # RSpec uses it's own mocking framework by default. If you prefer to
  # use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
end

module APIHelper
  def stub_libzmq
    @err_str_mock = mock("error string")
    
    LibZMQ.stub!(
    :zmq_init => 0,
    :zmq_errno => 0,
    :zmq_sterror => @err_str_mock
    )
  end
  
  # generate a random port between 10_000 and 65534
  def random_port
    rand(55534) + 10_000
  end
end
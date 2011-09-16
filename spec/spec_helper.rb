# To run these specs using rake, make sure the 'bones' and 'bones-extras'
# gems are installed. Then execute 'rake spec' from the main directory
# to run all specs.

require File.expand_path(
File.join(File.dirname(__FILE__), %w[.. lib ffi-rzmq]))

Thread.abort_on_exception = true

SPEC_CTX = ZMQ::Context.new 1
def spec_ctx
  SPEC_CTX
end

# define some version guards so we can turn on/off specs based upon
# the version of the 0mq library that is loaded
def version2?
  LibZMQ.version2?
end

def version3?
  LibZMQ.version3?
end

def version4?
  LibZMQ.version4?
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

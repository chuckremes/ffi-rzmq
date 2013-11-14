
require File.expand_path(
File.join(File.dirname(__FILE__), %w[.. lib ffi-rzmq]))

Thread.abort_on_exception = true

require 'openssl'
require 'socket'
require 'securerandom'

# define some version guards so we can turn on/off specs based upon
# the version of the 0mq library that is loaded
def version4?
  ZMQ::LibZMQ.version4?
end

def jruby?
  RUBY_PLATFORM =~ /java/
end


def connect_to_inproc(socket, endpoint)
  begin
    rc = socket.connect(endpoint)
  end until ZMQ::Util.resultcode_ok?(rc)
end

module APIHelper
  def poller_setup
    @helper_poller = ZMQ::Poller.new
  end

  def poller_register_socket(socket)
    @helper_poller.register(socket, ZMQ::POLLIN)
  end

  def poller_deregister_socket(socket)
    @helper_poller.deregister(socket, ZMQ::POLLIN)
  end

  def poll_delivery
    # timeout after 1 second
    @helper_poller.poll(1000)
  end

  def poll_it_for_read(socket, &blk)
    poller_register_socket(socket)
    blk.call
    poll_delivery
    poller_deregister_socket(socket)
  end

  # generate a random port between 10_000 and 65534
  def random_port
    rand(55534) + 10_000
  end

  def bind_to_random_tcp_port(socket, max_tries = 500)
    tries = 0
    rc = -1

    while !ZMQ::Util.resultcode_ok?(rc) && tries < max_tries
      tries += 1
      random = random_port
      rc = socket.bind(local_transport_string(random))
    end

    unless ZMQ::Util.resultcode_ok?(rc)
      raise "Could not bind to random port successfully; retries all failed!"
    end

    random
  end

  def connect_to_random_tcp_port socket, max_tries = 500
    tries = 0
    rc = -1

    while !ZMQ::Util.resultcode_ok?(rc) && tries < max_tries
      tries += 1
      random = random_port
      rc = socket.connect(local_transport_string(random))
    end

    unless ZMQ::Util.resultcode_ok?(rc)
      raise "Could not connect to random port successfully; retries all failed!"
    end

    random
  end

  def local_transport_string(port)
    "tcp://127.0.0.1:#{port}"
  end

  def assert_ok(rc)
    raise "Failed with rc [#{rc}] and errno [#{ZMQ::Util.errno}], msg [#{ZMQ::Util.error_string}]! #{caller(0)}" unless rc >= 0
  end
end

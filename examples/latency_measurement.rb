
require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rzmq')

# Within a single process, we start up two threads. One thread has a REQ (request)
# socket and the second thread has a REP (reply) socket. We measure the
# *round-trip* latency between these sockets. Only *one* message is in flight at
# any given moment.
#
# This example also illustrates how a single context can be shared amongst several
# threads. Sharing a single context also allows a user to specify the "inproc"
# transport in addition to "tcp" and "ipc".
#
#  % ruby latency_measurement.rb tcp://127.0.0.1:5555 1024 1_000_000
#
#  % ruby latency_measurement.rb inproc://lm_sock 1024 1_000_000
#

if ARGV.length < 3
  puts "usage: ruby latency_measurement.rb <connect-to> <message-size> <roundtrip-count>"
  exit
end

link = ARGV[0]
message_size = ARGV[1].to_i
roundtrip_count = ARGV[2].to_i

def assert(rc)
  raise "Last API call failed at #{caller(1)}" unless rc >= 0
end

begin
  master_context = ZMQ::Context.new
rescue ContextError => e
  STDERR.puts "Failed to allocate context or socket!"
  raise
end


class Receiver
  def initialize context, link, size, count
    @context = context
    @link = link
    @size = size
    @count = count

    begin
      @socket = @context.socket(ZMQ::REP)
    rescue ContextError => e
      STDERR.puts "Failed to allocate REP socket!"
      raise
    end

    assert(@socket.setsockopt(ZMQ::LINGER, 100))
    assert(@socket.setsockopt(ZMQ::RCVHWM, 100))
    assert(@socket.setsockopt(ZMQ::SNDHWM, 100))

    assert(@socket.bind(@link))
  end

  def run
    @count.times do
      string = ''
      assert(@socket.recv_string(string, 0))

      raise "Message size doesn't match, expected [#{@size}] but received [#{string.size}]" if @size != string.size

      assert(@socket.send_string(string, 0))
    end

    assert(@socket.close)
  end
end

class Transmitter
  def initialize context, link, size, count
    @context = context
    @link = link
    @size = size
    @count = count

    begin
      @socket = @context.socket(ZMQ::REQ)
    rescue ContextError => e
      STDERR.puts "Failed to allocate REP socket!"
      raise
    end

    assert(@socket.setsockopt(ZMQ::LINGER, 100))
    assert(@socket.setsockopt(ZMQ::RCVHWM, 100))
    assert(@socket.setsockopt(ZMQ::SNDHWM, 100))

    assert(@socket.connect(@link))
  end

  def run
    msg = "#{ '3' * @size }"

    elapsed = elapsed_microseconds do
      @count.times do
        assert(@socket.send_string(msg, 0))
        assert(@socket.recv_string(msg, 0))

        raise "Message size doesn't match, expected [#{@size}] but received [#{msg.size}]" if @size != msg.size
      end
    end

    latency = elapsed / @count / 2

    puts "message size: %i [B]" % @size
    puts "roundtrip count: %i" % @count
    puts "throughput (msgs/s): %i" % (@count / (elapsed / 1_000_000))
    puts "mean latency: %.3f [us]" % latency
    assert(@socket.close)
  end

  def elapsed_microseconds(&blk)
    start = Time.now
    yield
    value = ((Time.now - start) * 1_000_000)
  end
end

threads = []
threads << Thread.new do
  receiver = Receiver.new(master_context, link, message_size, roundtrip_count)
  receiver.run
end

sleep 1

threads << Thread.new do
  transmitter = Transmitter.new(master_context, link, message_size, roundtrip_count)
  transmitter.run
end

threads.each {|t| t.join}

master_context.terminate

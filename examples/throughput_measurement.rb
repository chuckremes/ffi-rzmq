require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'ffi-rzmq')
require 'thread'

# Within a single process, we start up five threads. Main thread has a PUB (publisher)
# socket and the secondary threads have SUB (subscription) sockets. We measure the
# *throughput* between these sockets. A high-water mark (HWM) is *not* set, so the
# publisher queue is free to grow to the size of memory without dropping packets.
#
# This example also illustrates how a single context can be shared amongst several
# threads. Sharing a single context also allows a user to specify the "inproc"
# transport in addition to "tcp" and "ipc".
#
#  % ruby throughput_measurement.rb tcp://127.0.0.1:5555 1024 1_000_000
#
#  % ruby throughput_measurement.rb inproc://lm_sock 1024 1_000_000
#

if ARGV.length < 3
  puts "usage: ruby throughput_measurement.rb <connect-to> <message-size> <roundtrip-count>"
  exit
end

link = ARGV[0]
message_size = ARGV[1].to_i
count = ARGV[2].to_i

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
  def initialize context, link, size, count, stats
    @context = context
    @link = link
    @size = size
    @count = count
    @stats = stats

    begin
      @socket = @context.socket(ZMQ::SUB)
    rescue ContextError => e
      STDERR.puts "Failed to allocate SUB socket!"
      raise
    end

    assert(@socket.setsockopt(ZMQ::LINGER, 100))
    assert(@socket.setsockopt(ZMQ::SUBSCRIBE, ""))

    assert(@socket.connect(@link))
  end

  def run
    msg = ZMQ::Message.new
    assert(@socket.recvmsg(msg))

    elapsed = elapsed_microseconds do
      (@count - 1).times do
        assert(@socket.recvmsg(msg))
      end
    end

    @stats.record_elapsed(elapsed)
    assert(@socket.close)
  end

  def elapsed_microseconds(&blk)
    start = Time.now
    yield
    ((Time.now - start) * 1_000_000)
  end
end

class Transmitter
  def initialize context, link, size, count
    @context = context
    @link = link
    @size = size
    @count = count

    begin
      @socket = @context.socket(ZMQ::PUB)
    rescue ContextError => e
      STDERR.puts "Failed to allocate PUB socket!"
      raise
    end

    assert(@socket.setsockopt(ZMQ::LINGER, 100))
    assert(@socket.bind(@link))
  end

  def run
    sleep 1
    contents = "#{'0' * @size}"

    i = 0
    while i < @count
      msg = ZMQ::Message.new(contents)
      assert(@socket.sendmsg(msg))
      i += 1
    end

  end
  
  def close
    assert(@socket.close)
  end
end

class Stats
  def initialize size, count
    @size = size
    @count = count
    
    @mutex = Mutex.new
    @elapsed = []
  end

  def record_elapsed(elapsed)
    @mutex.synchronize do
      @elapsed << elapsed
    end
  end

  def output
    @elapsed.each do |elapsed|
      throughput = @count * 1000000 / elapsed
      megabits = throughput * @size * 8 / 1000000

      puts "message size: %i [B]" % @size
      puts "message count: %i" % @count
      puts "mean throughput: %i [msg/s]" % throughput
      puts "mean throughput: %.3f [Mb/s]" % megabits
      puts
    end
  end
end

threads = []
stats = Stats.new message_size, count
transmitter = Transmitter.new(master_context, link, message_size, count)

threads << Thread.new do
  transmitter.run
end

1.times do
  threads << Thread.new do
    receiver = Receiver.new(master_context, link, message_size, count, stats)
    receiver.run
  end
end


threads.each {|t| t.join}
transmitter.close
stats.output

master_context.terminate

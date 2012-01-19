
require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'ffi-rzmq')

if ARGV.length < 3
  puts "usage: ruby local_lat.rb <connect-to> <message-size> <roundtrip-count>"
  exit
end

link = ARGV[0]
message_size = ARGV[1].to_i
roundtrip_count = ARGV[2].to_i

def assert(rc)
  raise "Last API call failed at #{caller(1)}" unless rc >= 0
end

begin
  ctx = ZMQ::Context.new
  s1 = ctx.socket(ZMQ::REQ)
  s2 = ctx.socket(ZMQ::REP)
rescue ContextError => e
  STDERR.puts "Failed to allocate context or socket!"
  raise
end

assert(s1.setsockopt(ZMQ::LINGER, 100))
assert(s2.setsockopt(ZMQ::LINGER, 100))

assert(s1.connect(link))
assert(s2.bind(link))

poller = ZMQ::Poller.new
poller.register_readable(s2)
poller.register_readable(s1)


start_time = Time.now

# kick it off
message = ZMQ::Message.new("a" * message_size)
assert(s1.sendmsg(message, ZMQ::NonBlocking))

i = roundtrip_count

until i.zero?
  i -= 1

  assert(poller.poll_nonblock)

  poller.readables.each do |socket|
    received_message = ''
    assert(socket.recv_string(received_message, ZMQ::NonBlocking))
    assert(socket.sendmsg(ZMQ::Message.new(received_message), ZMQ::NonBlocking))
  end
end

elapsed_usecs = (Time.now.to_f - start_time.to_f) * 1_000_000
latency = elapsed_usecs / roundtrip_count / 2

puts "mean latency: %.3f [us]" % latency
puts "received all messages in %.3f seconds" % (elapsed_usecs / 1_000_000)

assert(s1.close)
assert(s2.close)

ctx.terminate

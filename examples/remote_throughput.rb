
require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rzmq')

if ARGV.length != 3
  puts "usage: ruby remote_throughput.rb <connect-to> <message-size> <message-count>"
  Process.exit
end

connect_to = ARGV[0]
message_size = ARGV[1].to_i
message_count = ARGV[2].to_i

def assert(rc)
  raise "Last API call failed at #{caller(1)}" unless rc >= 0
end

begin
  ctx = ZMQ::Context.new
  s = ZMQ::Socket.new(ctx.pointer, ZMQ::PUB)
rescue ContextError => e
  STDERR.puts "Could not allocate a context or socket!"
  raise
end

#assert(s.setsockopt(ZMQ::LINGER, 1_000))
#assert(s.setsockopt(ZMQ::RCVHWM, 0))
#assert(s.setsockopt(ZMQ::SNDHWM, 0))
assert(s.connect(connect_to))

# give the downstream SUB socket a chance to register its
# subscription filters with this PUB socket
puts "Hit any key to start publishing"
STDIN.gets

contents = "#{'0'*message_size}"

i = 0
while i < message_count
  msg = ZMQ::Message.new(contents)
  assert(s.sendmsg(msg))
  puts i
  i += 1
end

sleep 10
assert(s.close)

ctx.terminate

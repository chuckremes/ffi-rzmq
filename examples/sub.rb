
require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rzmq')

#if ARGV.length != 3
#  puts "usage: ruby local_throughtput.rb <bind-to> <message-size> <message-count>"
#  Process.exit
#end

def assert(rc)
  raise "Last API call failed at #{caller(1)}" unless rc >= 0
end

bind_to = ARGV[0]
message_size = ARGV[1].to_i
message_count = ARGV[2].to_i
sleep_time = ARGV[3].to_f

begin
  ctx = ZMQ::Context.new
  s = ZMQ::Socket.new(ctx.pointer, ZMQ::SUB)
rescue ContextError => e
  STDERR.puts "Failed to allocate context or socket!"
  raise
end

#assert(s.setsockopt(ZMQ::LINGER, 100))
assert(s.setsockopt(ZMQ::SUBSCRIBE, ""))
assert(s.setsockopt(ZMQ::RCVHWM, 20))
#assert(s.setsockopt(ZMQ::RCVHWM, 0))
#assert(s.setsockopt(ZMQ::SNDHWM, 0))

assert(s.connect(bind_to))
sleep 1

msg = ZMQ::Message.new
msg = ''
assert(s.recv_string(msg))
raise unless msg.to_i == 0

start_time = Time.now

i = 1
while i < message_count
  assert(s.recv_string(msg))
  msg_i = msg.to_i
  puts "missed [#{msg_i - i}] messages"
  i = msg_i
  sleep(sleep_time)
end

end_time = Time.now

elapsed = (end_time.to_f - start_time.to_f) * 1000000
if elapsed == 0
  elapsed = 1
end

throughput = message_count * 1000000 / elapsed
megabits = throughput * message_size * 8 / 1000000

puts "message size: %i [B]" % message_size
puts "message count: %i" % message_count
puts "mean throughput: %i [msg/s]" % throughput
puts "mean throughput: %.3f [Mb/s]" % megabits

assert(s.close)

ctx.terminate

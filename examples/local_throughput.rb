require 'rubygems'
require 'ffi-rzmq'

if ARGV.length != 3
  puts "usage: local_thr <bind-to> <message-size> <message-count>"
  Process.exit
end

bind_to = ARGV[0]
message_size = ARGV[1].to_i
message_count = ARGV[2].to_i

ctx = ZMQ::Context.new
s = ZMQ::Socket.new ctx.pointer, ZMQ::SUB
s.setsockopt ZMQ::SUBSCRIBE, ""

s.bind bind_to

msg = ZMQ::Message.new
rc = s.recv msg

start_time = Time.now

i = 1
while i < message_count
  result_code = s.recv msg
  i += 1
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

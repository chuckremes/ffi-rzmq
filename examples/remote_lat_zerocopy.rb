require 'rubygems'
require 'ffi-rzmq'

if ARGV.length < 3
  puts "usage: remote_lat <connect-to> <message-size> <roundtrip-count>"
  exit
end

connect_to = ARGV[0]
message_size = ARGV[1].to_i
roundtrip_count = ARGV[2].to_i

ctx = ZMQ::Context.new 1, 1
s = ctx.socket ZMQ::REQ
s.connect connect_to

msg = ZMQ::Message.new "#{'3'*message_size}"

start_time = Time.now

roundtrip_count.times do
  s.send msg, 0
  result = s.recv msg, 0
  raise "Message size doesn't match, expected [#{message_size}] but received [#{msg.size}]" if message_size != msg.size
end

end_time = Time.now
elapsed_secs = (end_time.to_f - start_time.to_f)
elapsed_usecs = elapsed_secs * 1000000
latency = elapsed_usecs / roundtrip_count / 2

puts "message size: %i [B]" % message_size
puts "roundtrip count: %i" % roundtrip_count
puts "throughput (msgs/s): %i" % (roundtrip_count / elapsed_secs)
puts "mean latency: %.3f [us]" % latency

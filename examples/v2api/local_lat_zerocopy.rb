
begin
  require 'rubygems'
  require 'ffi-rzmq'
rescue LoadError
  require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'ffi-rzmq')
end

if ARGV.length < 3
  puts "usage: local_lat <connect-to> <message-size> <roundtrip-count>"
  exit
end

bind_to = ARGV[0]
message_size = ARGV[1].to_i
roundtrip_count = ARGV[2].to_i

ctx = ZMQ::Context.new 1
s = ZMQ::Socket.new ctx.context, ZMQ::REP
s.setsockopt ZMQ::HWM, 100
s.bind bind_to

msg = ZMQ::Message.new

roundtrip_count.times do
  result = s.recv msg, 0
  raise "Message size doesn't match, expected [#{message_size}] but received [#{msg.size}]" if message_size != msg.size
  s.send msg, 0
end

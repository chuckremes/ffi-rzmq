
begin
  require 'rubygems'
  require 'ffi-rzmq'
rescue LoadError
  require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'ffi-rzmq')
end

if ARGV.length != 3
	puts "usage: remote_thr <connect-to> <message-size> <message-count>"
	Process.exit
end
    
connect_to = ARGV[0]
message_size = ARGV[1].to_i
message_count = ARGV[2].to_i

ctx = ZMQ::Context.new
s = ZMQ::Socket.new ctx.pointer, ZMQ::PUB

s.connect connect_to

contents = "#{'0'*message_size}"

i = 0
while i < message_count
  msg = ZMQ::Message.new contents
	s.send msg
	i += 1
end

sleep 10

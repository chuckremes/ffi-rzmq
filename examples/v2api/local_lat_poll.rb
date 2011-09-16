
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

link = ARGV[0]
message_size = ARGV[1].to_i
roundtrip_count = ARGV[2].to_i

#link = "tcp://127.0.0.1:5555"

ctx = ZMQ::Context.new
s1 = ctx.socket ZMQ::REQ
s2 = ctx.socket ZMQ::REP

s1.connect link
s2.bind link

poller = ZMQ::Poller.new
poller.register_readable s2
poller.register_readable s1


start_time = Time.now

# kick it off
message = ZMQ::Message.new("a" * message_size)
s1.send message, ZMQ::NOBLOCK
i = roundtrip_count

until i.zero?
  i -= 1
  
  begin
    poller.poll_nonblock
  rescue ZMQ::PollError => e
    puts "efault? [#{e.efault?}]"
    raise
  end

  poller.readables.each do |socket|
    received_message = socket.recv_string ZMQ::NOBLOCK
    socket.send ZMQ::Message.new(received_message), ZMQ::NOBLOCK
  end  
end

elapsed_usecs = (Time.now.to_f - start_time.to_f) * 1_000_000
latency = elapsed_usecs / roundtrip_count / 2

puts "mean latency: %.3f [us]" % latency
puts "received all messages in %.3f seconds" % (elapsed_usecs / 1_000_000)

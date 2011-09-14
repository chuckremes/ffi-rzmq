require 'rubygems'
require 'ffi-rzmq'


link = "tcp://127.0.0.1:5555"

ctx = ZMQ::Context.new 1
s1 = ctx.socket ZMQ::XREQ
s1.identity = 'socket1.xreq'
s2 = ctx.socket ZMQ::XREP
s2.identity = 'socket2.xrep'
s3 = ctx.socket ZMQ::XREP
s3.identity = 'socket3.xrep'

s1.bind link
s2.connect link
#s3.connect link

poller = ZMQ::Poller.new
#poller.register_readable s3
poller.register_readable s2
poller.register_writable s1

start_time = Time.now
@unsent = true

until @done do
  begin
    poller.poll_nonblock
  rescue ZMQ::PollError => e
    puts "efault? [#{e.efault?}]"
    raise
  end

  # send the message after 5 seconds
  if Time.now - start_time > 5 && @unsent
    puts "sending payload nonblocking"

    5.times do |i|
      payload = "#{ i.to_s * 40 }"
      s1.send_string payload, ZMQ::NOBLOCK
    end
    @unsent = false
  end

  # check for messages after 1 second
  if Time.now - start_time > 1
    poller.readables.each do |sock|
      #p poller.readables
      puts
      #p poller.writables
      if sock.identity =~ /xrep/
        routing_info = sock.recv_string ZMQ::NOBLOCK
        puts "routing_info received [#{routing_info}] on socket.identity [#{sock.identity}]"
      else
        routing_info = nil
        received_msg = sock.recv_string ZMQ::NOBLOCK
        
        # skip to the next iteration if received_msg is nil; that means we got an EAGAIN
        next unless received_msg
        puts "message received [#{received_msg}] on socket.identity [#{sock.identity}]"
      end

      while sock.more_parts? do
        received_msg = sock.recv_string ZMQ::NOBLOCK

        puts "message received [#{received_msg}]"
      end

      puts "kick back a reply"
      sock.send_string routing_info, ZMQ::SNDMORE | ZMQ::NOBLOCK if routing_info
      time = Time.now.strftime "%Y-%m-%dT%H:%M:%S.#{Time.now.usec}"
      reply = "reply " + sock.identity.upcase + " #{time}"
      puts "sent reply [#{reply}], #{time}"
      sock.send_string reply
      @done = true
      poller.register_readable s1
    end
  end
end

puts "executed in [#{Time.now - start_time}] seconds"

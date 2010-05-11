require 'rubygems'
require 'ffi-rzmq'


link = "tcp://127.0.0.1:5555"

ctx = ZMQ::Context.new 1, 1, ZMQ::POLL
s1 = ctx.socket ZMQ::REQ
s2 = ctx.socket ZMQ::REP

s1.connect link
s2.bind link

poller = ZMQ::Poller.new
poller.register_readable s2
poller.register_writable s1

start_time = Time.now
@unsent = true

until @done do
  poller.poll_nonblock
  
  # send the message after 5 seconds
  if Time.now - start_time > 5 && @unsent
    payload = "#{ '3' * 1024 }"

    puts "sending payload nonblocking"
    s1.send_string payload, ZMQ::NOBLOCK
    @unsent = false
    puts "sent"
  end

  # check for messages after 1 second
  if Time.now - start_time > 1
    poller.readables.each do |sock|
      puts "receiving a msg with flags [#{ZMQ::NOBLOCK}]"
      received_msg = sock.recv_string ZMQ::NOBLOCK

      puts "message received [#{received_msg}]"
      @done = true
    end
  end
end

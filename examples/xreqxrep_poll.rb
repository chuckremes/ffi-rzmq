
require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rzmq')

def assert(rc)
  raise "Last API call failed at #{caller(1)}" unless rc >= 0
end

link = "tcp://127.0.0.1:5555"


begin
  ctx = ZMQ::Context.new
  s1 = ctx.socket(ZMQ::XREQ)
  s2 = ctx.socket(ZMQ::XREP)
rescue ContextError => e
  STDERR.puts "Failed to allocate context or socket"
  raise
end

s1.identity = 'socket1.xreq'
s2.identity = 'socket2.xrep'

assert(s1.setsockopt(ZMQ::LINGER, 100))
assert(s2.setsockopt(ZMQ::LINGER, 100))

assert(s1.bind(link))
assert(s2.connect(link))

poller = ZMQ::Poller.new
poller.register_readable(s2)
poller.register_writable(s1)

start_time = Time.now
@unsent = true

until @done do
  assert(poller.poll_nonblock)

  # send the message after 5 seconds
  if Time.now - start_time > 5 && @unsent
    puts "sending payload nonblocking"

    5.times do |i|
      payload = "#{ i.to_s * 40 }"
      assert(s1.send_string(payload, ZMQ::DONTWAIT))
    end
    @unsent = false
  end

  # check for messages after 1 second
  if Time.now - start_time > 1
    poller.readables.each do |sock|

      if sock.identity =~ /xrep/
        routing_info = ''
        assert(sock.recv_string(routing_info, ZMQ::DONTWAIT))
        puts "routing_info received [#{routing_info}] on socket.identity [#{sock.identity}]"
      else
        routing_info = nil
        received_msg = ''
        assert(sock.recv_string(received_msg, ZMQ::DONTWAIT))

        # skip to the next iteration if received_msg is nil; that means we got an EAGAIN
        next unless received_msg
        puts "message received [#{received_msg}] on socket.identity [#{sock.identity}]"
      end

      while sock.more_parts? do
        received_msg = ''
        assert(sock.recv_string(received_msg, ZMQ::DONTWAIT))

        puts "message received [#{received_msg}]"
      end

      puts "kick back a reply"
      assert(sock.send_string(routing_info, ZMQ::SNDMORE | ZMQ::DONTWAIT)) if routing_info
      time = Time.now.strftime "%Y-%m-%dT%H:%M:%S.#{Time.now.usec}"
      reply = "reply " + sock.identity.upcase + " #{time}"
      puts "sent reply [#{reply}], #{time}"
      assert(sock.send_string(reply))
      @done = true
      poller.register_readable(s1)
    end
  end
end

puts "executed in [#{Time.now - start_time}] seconds"

assert(s1.close)
assert(s2.close)

ctx.terminate

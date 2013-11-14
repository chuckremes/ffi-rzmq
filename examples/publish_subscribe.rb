require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rzmq')


def assert(rc)
  raise "Last API call failed at #{caller(1)}" unless rc >= 0
end

link = "tcp://127.0.0.1:5555"

begin
  ctx = ZMQ::Context.new
  s1 = ctx.socket(ZMQ::PUB)
  s2 = ctx.socket(ZMQ::SUB)
  s3 = ctx.socket(ZMQ::SUB)
  s4 = ctx.socket(ZMQ::SUB)
  s5 = ctx.socket(ZMQ::SUB)
rescue ContextError => e
  STDERR.puts "Failed to allocate context or socket!"
  raise
end

assert(s1.setsockopt(ZMQ::LINGER, 100))
assert(s2.setsockopt(ZMQ::SUBSCRIBE, '')) # receive all
assert(s3.setsockopt(ZMQ::SUBSCRIBE, 'animals')) # receive any starting with this string
assert(s4.setsockopt(ZMQ::SUBSCRIBE, 'animals.dog'))
assert(s5.setsockopt(ZMQ::SUBSCRIBE, 'animals.cat'))

assert(s1.bind(link))
assert(s2.connect(link))
assert(s3.connect(link))
assert(s4.connect(link))
assert(s5.connect(link))

sleep 1

topic = "animals.dog"
payload = "Animal crackers!"

s1.identity = "publisher-A"
puts "sending"
# use the new multi-part messaging support to
# automatically separate the topic from the body
assert(s1.send_string(topic, ZMQ::SNDMORE))
assert(s1.send_string(payload, ZMQ::SNDMORE))
assert(s1.send_string(s1.identity))

topic = ''
assert(s2.recv_string(topic))

body = ''
assert(s2.recv_string(body)) if s2.more_parts?

identity = ''
assert(s2.recv_string(identity)) if s2.more_parts?
puts "s2 received topic [#{topic}], body [#{body}], identity [#{identity}]"



topic = ''
assert(s3.recv_string(topic))

body = ''
assert(s3.recv_string(body)) if s3.more_parts?
puts "s3 received topic [#{topic}], body [#{body}]"

topic = ''
assert(s4.recv_string(topic))

body = ''
assert(s4.recv_string(body)) if s4.more_parts?
puts "s4 received topic [#{topic}], body [#{body}]"

s5_string = ''
rc = s5.recv_string(s5_string, ZMQ::DONTWAIT)
eagain = (rc == -1 && ZMQ::Util.errno == ZMQ::EAGAIN)
puts(eagain ? "s5 received no messages" : "s5 FAILED")

[s1, s2, s3, s4, s5].each do |socket|
  assert(socket.close)
end

ctx.terminate

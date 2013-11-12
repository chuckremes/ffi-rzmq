
require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'ffi-rzmq')


def assert(rc)
  raise "Last API call failed at #{caller(1)}" unless rc >= 0
end

link = "tcp://127.0.0.1:5555"

begin
  ctx = ZMQ::Context.new
  s1 = ctx.socket(ZMQ::REQ)
  s2 = ctx.socket(ZMQ::REP)
rescue ContextError => e
  STDERR.puts "Failed to allocate context or socket"
  raise
end

assert(s1.setsockopt(ZMQ::LINGER, 100))
assert(s2.setsockopt(ZMQ::LINGER, 100))

assert(s2.bind(link))
assert(s1.connect(link))

payload = "#{ '3' * 2048 }"
sent_msg = ZMQ::Message.new(payload)
received_msg = ZMQ::Message.new

assert(s1.sendmsg(sent_msg))
assert(s2.recvmsg(received_msg))

result = payload == received_msg.copy_out_string ? "Request received" : "Received wrong payload"

p result

assert(s1.close)
assert(s2.close)

ctx.terminate

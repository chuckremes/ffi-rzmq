
begin
  require 'rubygems'
  require 'ffi-rzmq'
rescue LoadError
  require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'ffi-rzmq')
end


link = "tcp://127.0.0.1:5555"

ctx = ZMQ::Context.new 1
s1 = ctx.socket ZMQ::REQ
s2 = ctx.socket ZMQ::REP

s2.bind link
s1.connect link

payload = "#{ '3' * 2048 }"
sent_msg = ZMQ::Message.new payload
received_msg = ZMQ::Message.new

s1.send sent_msg
s2.recv received_msg

result = payload == received_msg.copy_out_string ? "Request received" : "Received wrong payload"

p result

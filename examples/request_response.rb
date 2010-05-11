require 'rubygems'
require 'ffi-rzmq'


link = "tcp://127.0.0.1:5555"
message_size = 1024

ctx = ZMQ::Context.new 1, 1, 0
s1 = ctx.socket ZMQ::REQ
s2 = ctx.socket ZMQ::REP

s1.connect link
s2.bind link

payload = "#{ '3' * message_size }"
sent_msg = ZMQ::Message.new payload
received_msg = ZMQ::Message.new

s1.send sent_msg
s2.recv received_msg

result = payload == received_msg.data_as_string ? "Request received" : "Received wrong payload"

p result
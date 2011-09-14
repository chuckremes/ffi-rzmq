require 'rubygems'
require 'ffi-rzmq'


link = "tcp://127.0.0.1:5555"

ctx = ZMQ::Context.new 1
s1 = ctx.socket ZMQ::PUB
s2 = ctx.socket ZMQ::SUB
s3 = ctx.socket ZMQ::SUB
s4 = ctx.socket ZMQ::SUB
s5 = ctx.socket ZMQ::SUB

s2.setsockopt ZMQ::SUBSCRIBE, '' # receive all
s3.setsockopt ZMQ::SUBSCRIBE, 'animals' # receive any starting with this string
s4.setsockopt ZMQ::SUBSCRIBE, 'animals.dog'
s5.setsockopt ZMQ::SUBSCRIBE, 'animals.cat'

s1.bind link
s2.connect link
s3.connect link
s4.connect link
s5.connect link

sleep 1

topic = "animals.dog"
payload = "Animal crackers!"

s1.identity = "publisher-A"
puts "sending"
# use the new multi-part messaging support to
# automatically separate the topic from the body
s1.send_string topic, ZMQ::SNDMORE
s1.send_string payload, ZMQ::SNDMORE
s1.send_string s1.identity

topic = s2.recv_string
body = s2.recv_string if s2.more_parts?
identity = s2.recv_string if s2.more_parts?
puts "s2 received topic [#{topic}], body [#{body}], identity [#{identity}]"

topic = s3.recv_string
body = s3.recv_string if s3.more_parts?
puts "s3 received topic [#{topic}], body [#{body}]"

topic = s4.recv_string
body = s4.recv_string if s4.more_parts?
puts "s4 received topic [#{topic}], body [#{body}]"

s5_string = s5.recv_string ZMQ::NOBLOCK
puts(s5_string.nil? ? "s5 received no messages" : "s5 FAILED")

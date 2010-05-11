require 'rubygems'
require 'ffi-rzmq'


link = "tcp://127.0.0.1:5555"

ctx = ZMQ::Context.new 1, 1, 0
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

payload = "animals.dog|Animal crackers!"

puts "sending"
s1.send_string payload

s2_string = s2.recv_string
topic = s2_string.split('|').first
body = s2_string.split('|').last
puts "s2 received topic [#{topic}], body [#{body}]"

s3_string = s3.recv_string
topic = s3_string.split('|').first
body = s3_string.split('|').last
puts "s3 received topic [#{topic}], body [#{body}]"

s4_string = s4.recv_string
topic = s4_string.split('|').first
body = s4_string.split('|').last
puts "s4 received topic [#{topic}], body [#{body}]"

s5_string = s5.recv_string ZMQ::NOBLOCK
puts(s5_string.nil? ? "s5 received no messages" : "s5 FAILED")

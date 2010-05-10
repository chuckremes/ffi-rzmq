#
#    Copyright (c) 2007-2010 iMatix Corporation
#
#    This file is part of 0MQ.
#
#    0MQ is free software; you can redistribute it and/or modify it under
#    the terms of the Lesser GNU General Public License as published by
#    the Free Software Foundation; either version 3 of the License, or
#    (at your option) any later version.
#
#    0MQ is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    Lesser GNU General Public License for more details.
#
#    You should have received a copy of the Lesser GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'ffi-rzmq'

if ARGV.length != 4
  puts "usage: remote_lat <connect-to> <message-size> <roundtrip-count> <manual memory mgmt>"
  exit
end

connect_to = ARGV[0]
message_size = ARGV[1].to_i
roundtrip_count = ARGV[2].to_i
auto_mgmt = ARGV[3].to_i.zero?

if auto_mgmt
  message_opts = {}
else
  message_opts = {:receiver_class => ZMQ::UnmanagedMessage, :sender_class => ZMQ::UnmanagedMessage}
end

ctx = ZMQ::Context.new(1, 1, 0)
s = auto_mgmt ? ctx.socket(ZMQ::REQ) : ZMQ::Socket.new(ctx.context, ZMQ::REQ, message_opts)
s.connect(connect_to)

msg = ZMQ::Message.new "#{'0'*message_size}"

start_time = Time.now

roundtrip_count.times do
  s.send msg, 0
  msg = s.recv msg, 0
  raise "Message size doesn't match" if message_size != msg.size
end

msg.close unless auto_mgmt

end_time = Time.now
elapsed_secs = (end_time.to_f - start_time.to_f)
elapsed_usecs = elapsed_secs * 1000000
latency = elapsed_usecs / roundtrip_count / 2

puts "message size: %i [B]" % message_size
puts "roundtrip count: %i" % roundtrip_count
puts "throughput (msgs/s): %i" % (roundtrip_count / elapsed_secs)
puts "mean latency: %.3f [us]" % latency

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

begin
  require 'rubygems'
  require 'ffi-rzmq'
rescue LoadError
  require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'ffi-rzmq')
end

if ARGV.length < 3
  puts "usage: local_lat <connect-to> <message-size> <roundtrip-count>"
  exit
end

bind_to = ARGV[0]
message_size = ARGV[1].to_i
roundtrip_count = ARGV[2].to_i

ctx = ZMQ::Context.new 1
s = ctx.socket ZMQ::REP
s.setsockopt(ZMQ::HWM, 100)
s.bind(bind_to)

roundtrip_count.times do
  msg = s.recv_string 0
  raise "Message size doesn't match, expected [#{message_size}] but received [#{msg.size}]" if message_size != msg.size
  s.send_string msg, 0
end

# give the lib time to flush any remaining messages
sleep 1

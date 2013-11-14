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

require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rzmq')

if ARGV.length < 3
  puts "usage: ruby local_lat.rb <connect-to> <message-size> <roundtrip-count>"
  exit
end

bind_to = ARGV[0]
message_size = ARGV[1].to_i
roundtrip_count = ARGV[2].to_i

def assert(rc)
  raise "Last API call failed at #{caller(1)}" unless rc >= 0
end

begin
  ctx = ZMQ::Context.new
  s = ctx.socket(ZMQ::REP)
rescue ContextError => e
  STDERR.puts "Failed to allocate context or socket!"
  raise
end

assert(s.setsockopt(ZMQ::LINGER, 100))
assert(s.setsockopt(ZMQ::RCVHWM, 100))
assert(s.setsockopt(ZMQ::SNDHWM, 100))

assert(s.bind(bind_to))

roundtrip_count.times do
  string = ''
  assert(s.recv_string(string, 0))

  raise "Message size doesn't match, expected [#{message_size}] but received [#{string.size}]" if message_size != string.size

  assert(s.send_string(string, 0))
end

assert(s.close)

ctx.terminate

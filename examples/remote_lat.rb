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
  puts "usage: ruby remote_lat.rb <connect-to> <message-size> <roundtrip-count>"
  exit
end

def assert(rc)
  raise "Last API call failed at #{caller(1)}" unless rc >= 0
end

connect_to = ARGV[0]
message_size = ARGV[1].to_i
roundtrip_count = ARGV[2].to_i

begin
  ctx = ZMQ::Context.new
  s = ctx.socket(ZMQ::REQ)
rescue ContextError => e
  STDERR.puts "Failed to allocate context or socket!"
  raise
end

assert(s.setsockopt(ZMQ::LINGER, 100))
assert(s.connect(connect_to))

msg = "#{ '3' * message_size }"

start_time = Time.now

roundtrip_count.times do
  assert(s.send_string(msg, 0))

  msg = ''
  assert(s.recv_string(msg, 0))

  raise "Message size doesn't match, expected [#{message_size}] but received [#{msg.size}]" if message_size != msg.size
end

end_time = Time.now
elapsed_secs = (end_time.to_f - start_time.to_f)
elapsed_usecs = elapsed_secs * 1000000
latency = elapsed_usecs / roundtrip_count / 2

puts "message size: %i [B]" % message_size
puts "roundtrip count: %i" % roundtrip_count
puts "throughput (msgs/s): %i" % (roundtrip_count / elapsed_secs)
puts "mean latency: %.3f [us]" % latency

assert(s.close)

ctx.terminate

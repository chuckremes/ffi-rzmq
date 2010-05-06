ffi-rzmq
    by Chuck Remes
    http://github.com/chuckremes/ffi-rzmq

== DESCRIPTION:

This gem wraps the zeromq networking library using the ruby FFI (foreign 
function interface). It's a pure ruby wrapper so this gem can be loaded
and run by any ruby runtime that supports FFI.

The impetus behind this library was to provide support for zeromq in
JRuby which has native threads. Unlike MRI, MacRuby, IronRuby and
Rubinius which all have a GIL, JRuby allows for threaded access to ruby
code from outside extensions. Zeromq is heavily threaded, so until the
other runtimes remove their GIL, JRuby will likely be the best
environment to run this library.

== PERFORMANCE

Using FFI introduces significant and measurable overhead. When comparing
the performance of the zeromq library using that project's official
ruby bindings running under MRI 1.9.1-p378 to this project running under
JRuby 1.5RC3, the results showed the FFI bindings to be consistently 
slower in a single-threaded test.

Using the example code from below, MRI to MRI with a 2048 byte message
would average around 49 usec. The same test using JRuby would average
around 55 usec. These values would fluctuate depending on the size and
number of messages used in the test.

The hope is that in a multi-threaded environment that JRuby's native
threads and lack of GIL will compensate for the FFI overhead.

== FEATURES/PROBLEMS:

This gem is brand new and has no tests at all. I'm certain there are a
ton of bugs, so please open issues for them here or fork this project,
fix them, and send me a pull request.

== SYNOPSIS:

Client code:
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

require 'ffi-rzmq'

if ARGV.length != 3
	puts "usage: local_lat <bind-to> <message-size> <roundtrip-count>"
	Process.exit
end
    
bind_to = ARGV[0]
message_size = ARGV[1].to_i
roundtrip_count = ARGV[2].to_i
			
ctx = ZMQ::Context.new(1, 1, 0)
s = ctx.socket(ZMQ::REP);
s.setsockopt(ZMQ::HWM, 100);
s.bind(bind_to);

for i in 0...roundtrip_count do
    msg = s.recv(0)
    s.send(msg, 0)
end

sleep 1


Server code:

require 'ffi-rzmq'

if ARGV.length != 3
	puts "usage: remote_lat <connect-to> <message-size> <roundtrip-count>"
    Process.exit
end

connect_to = ARGV[0]
message_size = ARGV[1].to_i
roundtrip_count = ARGV[2].to_i
					
ctx = ZMQ::Context.new(1, 1, 0)
s = ctx.socket(ZMQ::REQ);
s.connect(connect_to);

msg = "#{'0'*message_size}"

start_time = Time.now

for i in 0...roundtrip_count do
    s.send(msg, 0)
    msg = s.recv(0)
end

end_time = Time.now

elapsed = (end_time.to_f - start_time.to_f) * 1000000
latency = elapsed / roundtrip_count / 2

puts "message size: %i [B]" % message_size
puts "roundtrip count: %i" % roundtrip_count
puts "mean latency: %.3f [us]" % latency

== REQUIREMENTS:

The Zeromq library must be installed on your system in a well-known location
like /usr/local/lib. This is the default for new zeromq installs.

== INSTALL:

Make sure the zeromq library is already installed on your system.

 % gem build ffi-rzmq.gemspec
 % gem install ffi-rzmq-0.1.0.gem
 

== LICENSE:

(The MIT License)

Copyright (c) 2009 Chuck Remes

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

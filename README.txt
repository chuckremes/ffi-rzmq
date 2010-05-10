ffi-rzmq
    by Chuck Remes
    http://www.zeromq.org/bindings:ruby-ffi

== DESCRIPTION:

This gem wraps the ZeroMQ networking library using the ruby FFI (foreign
function interface). It's a pure ruby wrapper so this gem can be loaded
and run by any ruby runtime that supports FFI. Right now that means
MRI 1.8.7, 1.9.1 and JRuby.

The impetus behind this library was to provide support for ZeroMQ in
JRuby which has native threads. Unlike MRI, MacRuby, IronRuby and
Rubinius which all have a GIL, JRuby allows for threaded access to ruby
code from outside extensions. ZeroMQ is heavily threaded, so until the
other runtimes remove their GIL, JRuby will likely be the best
environment to run this library.

== PERFORMANCE

Using FFI introduces some minimal overhead. In my latest benchmarks,
I was unable to detect any measurable performance drop due to FFI
regardless of which ruby runtime was tested. JRuby had the best overall
performance (with --server) once it warmed up. MRI behaved quite well 
too and has a much lower memory footprint than JRuby.

The hope is that in a multi-threaded environment that JRuby's native
threads and lack of GIL will provide the best ZeroMQ performance using
the ruby language.

== FEATURES/PROBLEMS:

This gem is brand new and has no tests at all. I'm certain there are a
ton of bugs, so please open issues for them here or fork this project,
fix them, and send me a pull request.

All features are implemented with the exception of #zmq_poll. I'll add
it as soon as I am able.

== SYNOPSIS:

Client code:
  
  require 'rubygems'
  require 'ffi-rzmq'

  if ARGV.length != 4
    puts "usage: local_lat <connect-to> <message-size> <roundtrip-count> <manual memory mgmt>"
    exit
  end

  bind_to = ARGV[0]
  message_size = ARGV[1].to_i
  roundtrip_count = ARGV[2].to_i
  auto_mgmt = ARGV[3].to_i.zero?

  if auto_mgmt
    message_opts = {}
  else
    message_opts = {:receiver_class => ZMQ::UnmanagedMessage, :sender_class => ZMQ::UnmanagedMessage}
  end

  ctx = ZMQ::Context.new(1, 1, 0)
  s = auto_mgmt ? ctx.socket(ZMQ::REP) : ZMQ::Socket.new(ctx.context, ZMQ::REP, message_opts)
  s.setsockopt(ZMQ::HWM, 100)
  s.setsockopt(ZMQ::LWM, 90) # level to restart when congestion is relieved
  s.bind(bind_to)

  msg = ZMQ::Message.new

  roundtrip_count.times do
    msg = s.recv msg, 0
    raise "Message size doesn't match" if message_size != msg.size
    s.send msg, 0
  end

  msg.close unless auto_mgmt

Server code:

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

== REQUIREMENTS:

The ZeroMQ library must be installed on your system in a well-known location
like /usr/local/lib. This is the default for new ZeroMQ installs.

Future releases may include the library as a C extension built at
time of installation.

== INSTALL:

Make sure the ZeroMQ library is already installed on your system.

 % gem build ffi-rzmq.gemspec
 % gem install ffi-rzmq-*.gem
 

== LICENSE:

(The MIT License)

Copyright (c) 2010 Chuck Remes

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

# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ffi-rzmq}
  s.version = "0.7.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Chuck Remes"]
  s.date = %q{2010-12-22}
  s.description = %q{This gem wraps the ZeroMQ networking library using the ruby FFI (foreign
function interface). It's a pure ruby wrapper so this gem can be loaded
and run by any ruby runtime that supports FFI. That's all of them:
MRI 1.9.x, Rubinius and JRuby.

The impetus behind this library was to provide support for ZeroMQ in
JRuby which has native threads. Unlike MRI, IronRuby and
Rubinius which all have a GIL, JRuby allows for threaded access to ruby
code from outside extensions. ZeroMQ is heavily threaded, so until the
other runtimes remove their GIL, JRuby will likely be the best
environment to run this library.}
  s.email = %q{cremes@mac.com}
  s.extra_rdoc_files = ["History.txt", "README.rdoc", "examples/README.rdoc", "version.txt"]
  s.files = [".bnsignore", "History.txt", "README.rdoc", "Rakefile", "examples/README.rdoc", "examples/local_lat.rb", "examples/local_lat_poll.rb", "examples/local_lat_zerocopy.rb", "examples/local_throughput.rb", "examples/publish_subscribe.rb", "examples/remote_lat.rb", "examples/remote_lat_zerocopy.rb", "examples/remote_throughput.rb", "examples/reqrep_poll.rb", "examples/request_response.rb", "examples/xreqxrep_poll.rb", "ffi-rzmq.gemspec", "lib/ffi-rzmq.rb", "lib/ffi-rzmq/context.rb", "lib/ffi-rzmq/exceptions.rb", "lib/ffi-rzmq/message.rb", "lib/ffi-rzmq/poll.rb", "lib/ffi-rzmq/poll_items.rb", "lib/ffi-rzmq/socket.rb", "lib/ffi-rzmq/wrapper.rb", "lib/ffi-rzmq/zmq.rb", "spec/context_spec.rb", "spec/message_spec.rb", "spec/pushpull_spec.rb", "spec/reqrep_spec.rb", "spec/socket_spec.rb", "spec/spec_helper.rb", "version.txt"]
  s.homepage = %q{http://github.com/chuckremes/ffi-rzmq}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{ffi-rzmq}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{This gem wraps the ZeroMQ networking library using the ruby FFI (foreign function interface).}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bones>, [">= 3.5.4"])
    else
      s.add_dependency(%q<bones>, [">= 3.5.4"])
    end
  else
    s.add_dependency(%q<bones>, [">= 3.5.4"])
  end
end

# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ffi-rzmq}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Chuck Remes"]
  s.date = %q{2010-05-06}
  s.description = %q{This gem wraps the zeromq networking library using the ruby FFI (foreign  function interface). It's a pure ruby wrapper so this gem can be loaded and run by any ruby runtime that supports FFI.  The impetus behind this library was to provide support for zeromq in JRuby which has native threads. Unlike MRI, MacRuby, IronRuby and Rubinius which all have a GIL, JRuby allows for threaded access to ruby code from outside extensions. Zeromq is heavily threaded, so until the other runtimes remove their GIL, JRuby will likely be the best environment to run this library.}
  s.email = %q{cremes@mac.com}
  s.extra_rdoc_files = ["History.txt", "README.txt", "version.txt"]
  s.files = ["History.txt", "README.txt", "Rakefile", "lib/ffi-rzmq.rb", "lib/ffi-rzmq/ffi.rb", "lib/ffi-rzmq/zmq.rb", "spec/ffi-rzmq_spec.rb", "spec/spec_helper.rb", "version.txt"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/chuckremes/ffi-rzmq}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{ffi-rzmq}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{This gem wraps the zeromq networking library using the ruby FFI (foreign  function interface)}

  # useless without FFI, so add it!
  s.add_dependency "ffi", ">= 0"

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bones>, [">= 3.4.1"])
    else
      s.add_dependency(%q<bones>, [">= 3.4.1"])
    end
  else
    s.add_dependency(%q<bones>, [">= 3.4.1"])
  end
end

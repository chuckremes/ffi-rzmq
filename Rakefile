begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default => 'test:run'
task 'gem:release' => 'test:run'

namespace :win do

  desc 'Build and install gem under Windows. Mr Bones just has to break things using tar.'
  task :install do
    PKG_PATH = File.join(File.dirname(__FILE__), 'pkg')
    NAME = File.basename(File.dirname(__FILE__))
    rm_rf PKG_PATH
    system "gem build #{NAME}.gemspec"
    mkdir_p PKG_PATH
    mv "#{NAME}-0.6.0.gem", PKG_PATH
    system "gem install #{PKG_PATH}/#{NAME}-0.6.0.gem"
  end
end

Bones {
  name 'ffi-rzmq'
  authors 'Chuck Remes'
  email 'cremes@mac.com'
  url 'http://github.com/chuckremes/ffi-rzmq'
  readme_file 'README.rdoc'
  ruby_opts.clear # turn off warnings
}


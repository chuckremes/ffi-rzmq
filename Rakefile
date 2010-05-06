
begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default => 'test:run'
task 'gem:release' => 'test:run'

Bones {
  name  'ffi-rzmq'
  authors  'Chuck Remes'
  email    'cremes@mac.com'
  url      'FIXME (project homepage)'
}


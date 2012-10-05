class IO
  if defined? JRUBY_VERSION
    require 'jruby'
    def posix_fileno
      case self
      when STDIN, $stdin
        0
      when STDOUT, $stdout
        1
      when STDERR, $stderr
        2
      else
        JRuby.reference(self).getOpenFile.getMainStream.getDescriptor.getChannel.getFDVal
      end
    end
  else
    alias :posix_fileno :fileno
  end
end

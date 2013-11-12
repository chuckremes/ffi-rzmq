module ZMQ

  class Device
    attr_reader :device

    def self.create(frontend, backend, capture=nil)
      dev = nil
      begin
        dev = new(frontend, backend, capture)
      rescue ArgumentError
        dev = nil
      end

      dev
    end

    def initialize(frontend, backend, capture=nil)
      [["frontend", frontend], ["backend", backend]].each do |name, socket|
        unless socket.is_a?(ZMQ::Socket)
          raise ArgumentError, "Expected a ZMQ::Socket, not a #{socket.class} as the #{name}"
        end
      end

      LibZMQ.zmq_proxy(frontend.socket, backend.socket, capture ? capture.socket : nil)
    end
  end
  
  # Alias for Device
  #
  class Proxy < Device; end

end

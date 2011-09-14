module ZMQ
  if LibZMQ.version2?
    class Device
      attr_reader :device

      def initialize(device_type,frontend,backend)
        [["frontend", frontend],["backend", backend]].each do |name,socket|
          unless socket.is_a?(ZMQ::Socket)
            raise ArgumentError, "Expected a ZMQ::Socket, not a #{socket.class} as the #{name}"
          end
        end

        LibZMQ.zmq_device(device_type, frontend.socket, backend.socket)
      end
    end
  end
end

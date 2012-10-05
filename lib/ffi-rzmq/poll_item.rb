require 'forwardable'
require 'io_extensions'

module ZMQ
  class PollItem
    extend Forwardable

    def_delegators :@poll_item, :pointer, :readable?, :writable?
    attr_accessor :pollable, :poll_item

    def initialize(zmq_poll_item = nil)
      @poll_item = zmq_poll_item || LibZMQ::PollItem.new
    end

    def self.from_pointer(pointer)
      self.new(LibZMQ::PollItem.new(pointer))
    end

    def self.from_pollable(pollable)
      item = self.new
      item.pollable = pollable
      case
      when pollable.respond_to?(:socket)
        item.socket = pollable.socket
      when pollable.respond_to?(:posix_fileno)
        item.fd = pollable.posix_fileno
      when pollable.respond_to?(:io)
        item.fd = pollable.io.posix_fileno
      end
      item
    end

    def closed?
      case
      when pollable.respond_to?(:closed?)
        pollable.closed?
      when pollable.respond_to?(:socket)
        pollable.socket.nil?
      when pollable.respond_to?(:io)
        pollable.io.closed?
      end
    end

    def socket=(arg); @poll_item[:socket] = arg; end

    def socket; @poll_item[:socket]; end

    def fd=(arg); @poll_item[:fd] = arg; end

    def fd; @poll_item[:fd]; end

    def events=(arg); @poll_item[:events] = arg; end

    def events; @poll_item[:events]; end
  end
end

require 'spec_helper'

module ZMQ

  describe Poller do

    context "when initializing" do
      include APIHelper

      it "should allocate a PollItems instance" do
        PollItems.should_receive(:new)
        Poller.new
      end

    end

    context "#register" do

      let(:pollable) { mock('pollable') }
      let(:poller) { Poller.new }
      let(:socket) { FFI::MemoryPointer.new(4) }
      let(:io) { stub(:posix_fileno => fd) }
      let(:fd) { 1 }

      it "returns false when given a nil pollable" do
        poller.register(nil, ZMQ::POLLIN).should be_false
      end

      it "returns false when given 0 for +events+ (e.g. no registration)" do
        poller.register(pollable, 0).should be_false
      end

      it "returns the default registered event value when given a valid pollable" do
        poller.register(pollable).should == (ZMQ::POLLIN | ZMQ::POLLOUT)
      end

      it "returns the registered event value when given a pollable responding to socket (ZMQ::Socket)" do
        pollable.should_receive(:socket).and_return(socket)
        poller.register(pollable, ZMQ::POLLIN).should == ZMQ::POLLIN
      end

      it "returns the registered event value when given a pollable responding to file descriptor (IO, BasicSocket)" do
        pollable.should_receive(:posix_fileno).and_return(fd)
        poller.register(pollable, ZMQ::POLLIN).should == ZMQ::POLLIN
      end

      it "returns the registered event value when given a pollable responding to io (SSLSocket)" do
        pollable.should_receive(:io).and_return(io)
        poller.register(pollable, ZMQ::POLLIN).should == ZMQ::POLLIN
      end

    end

    context "#deregister" do

      let(:pollable) { mock('pollable') }
      let(:poller) { Poller.new }
      let(:socket) { FFI::MemoryPointer.new(4) }
      let(:io) { stub(:posix_fileno => fd) }
      let(:fd) { 1 }

      it "returns true when deregistered pollable from event" do
        pollable.should_receive(:socket).at_least(:once).and_return(socket)
        poller.register(pollable)
        poller.deregister(pollable, ZMQ::POLLIN).should be_true
      end

      it "returns false when pollable not registered" do
        poller.deregister(pollable, ZMQ::POLLIN).should be_false
      end

      it "returns false when pollable not registered for deregistered event" do
        pollable.should_receive(:socket).at_least(:once).and_return(socket)
        poller.register(pollable, ZMQ::POLLOUT)
        poller.deregister(pollable, ZMQ::POLLIN).should be_false
      end

      it "deletes pollable when no events left" do
        poller.register(pollable, ZMQ::POLLIN)
        poller.deregister(pollable, ZMQ::POLLIN).should be_true
        poller.size.should == 0
      end

      it "deletes closed pollable responding to socket (ZMQ::Socket)" do
        pollable.should_receive(:socket).and_return(socket)
        poller.register(pollable)
        pollable.should_receive(:socket).and_return(nil)
        poller.deregister(pollable, ZMQ::POLLIN).should be_true
        poller.size.should == 0
      end

      it "deletes closed pollable responding to fileno (IO, BasicSocket)" do
        pollable.should_receive(:posix_fileno).and_return(fd)
        poller.register(pollable)
        pollable.should_receive(:closed?).and_return(true)
        poller.deregister(pollable, ZMQ::POLLIN).should be_true
        poller.size.should == 0
      end

      it "deletes closed pollable responding to io (SSLSocket)" do
        pollable.should_receive(:io).at_least(:once).and_return(io)
        poller.register(pollable)
        io.should_receive(:closed?).and_return(true)
        poller.deregister(pollable, ZMQ::POLLIN).should be_true
        poller.size.should == 0
      end

    end

    context "#delete" do

      before(:all) { @context = Context.new }
      after(:all)  { @context.terminate }

      before(:each) do
        @socket = @context.socket(XREQ)
        @socket.setsockopt(LINGER, 0)
        @poller = Poller.new
      end

      after(:each) do
        @socket.close
      end

      it "should return false for an unregistered socket (i.e. not found)" do
        @poller.delete(@socket).should be_false
      end

      it "returns true for a sucessfully deleted socket when only 1 is registered" do
        socket1 = @context.socket(REP)
        socket1.setsockopt(LINGER, 0)

        @poller.register socket1
        @poller.delete(socket1).should be_true
        socket1.close
      end

      it "returns true for a sucessfully deleted socket when more than 1 is registered" do
        socket1 = @context.socket(REP)
        socket2 = @context.socket(REP)
        socket1.setsockopt(LINGER, 0)
        socket2.setsockopt(LINGER, 0)

        @poller.register socket1
        @poller.register socket2
        @poller.delete(socket2).should be_true
        socket1.close
        socket2.close
      end

      it "returns true for a successfully deleted socket when the socket has been previously closed" do
        socket1 = @context.socket(REP)
        socket1.setsockopt(LINGER, 0)

        @poller.register socket1
        socket1.close
        @poller.delete(socket1).should be_true
      end

    end

    context "poll" do
      include APIHelper

      before(:all) { @context = Context.new }
      after(:all)  { @context.terminate }

      before(:each) do
        endpoint = "inproc://poll_test_#{SecureRandom.hex}"
        @sockets = [@context.socket(DEALER), @context.socket(ROUTER)]
        @sockets.each { |s| s.setsockopt(LINGER, 0) }
        @sockets.first.bind(endpoint)
        connect_to_inproc(@sockets.last, endpoint)
        @poller = Poller.new
      end

      after(:each) { @sockets.each(&:close) }

      it "returns 0 when there are no sockets to poll" do
        @poller.poll(100).should be_zero
      end

      it "returns 0 when there is a single socket to poll and no events" do
        @poller.register(@sockets.first, 0)
        @poller.poll(100).should be_zero
      end

      it "returns 1 when there is a read event on a socket" do
        first, last = @sockets
        @poller.register_readable(last)

        first.send_string('test')
        @poller.poll(1000).should == 1
      end

      it "returns 1 when there is a read event on one socket and the second socket has been removed from polling" do
        first, last = @sockets
        @poller.register_readable(last)
        @poller.register_writable(first)

        first.send_string('test')
        @poller.deregister_writable(first)
        @poller.poll(1000).should == 1
      end

      it "works with BasiSocket" do
        server = TCPServer.new("127.0.0.1", 0)
        f, port, host, addr = server.addr
        client = TCPSocket.new("127.0.0.1", port)
        s = server.accept

        @poller.register(s, ZMQ::POLLIN)
        @poller.register(client, ZMQ::POLLOUT)

        client.send("message", 0)

        @poller.poll.should == 2
        @poller.readables.should == [s]
        @poller.writables.should == [client]

        msg = s.read_nonblock(7)
        msg.should == "message"
      end

      it "works with IO objects" do
        r, w = IO.pipe
        @poller.register(r, ZMQ::POLLIN)
        @poller.register(w, ZMQ::POLLOUT)

        w.write("message")

        @poller.poll.should == 2
        @poller.readables.should == [r]
        @poller.writables.should == [w]

        msg = r.read(7)
        msg.should == "message"
      end

      it "works with SSLSocket" do
        crt, key = %w[crt key].map { |ext| File.read(File.join(File.dirname(__FILE__), "support", "test." << ext)) }

        ctx = OpenSSL::SSL::SSLContext.new
        ctx.key  = OpenSSL::PKey::RSA.new(key)
        ctx.cert = OpenSSL::X509::Certificate.new(crt)

        server = TCPServer.new("127.0.0.1", 0)
        f, port, host, addr = server.addr
        client = TCPSocket.new("127.0.0.1", port)
        s = server.accept

        client = OpenSSL::SSL::SSLSocket.new(client)

        server = OpenSSL::SSL::SSLSocket.new(s, ctx)

        t = Thread.new { client.connect }
        s = server.accept
        t.join

        @poller.register_readable(s)
        @poller.register_writable(client)

        client.write("message")

        @poller.poll.should == 2
        @poller.readables.should == [s]
        @poller.writables.should == [client]

        msg = s.read(7)
        msg.should == "message"
      end
    end

  end

end

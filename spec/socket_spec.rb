
require File.join(File.dirname(__FILE__), %w[spec_helper])

module ZMQ


  describe Socket do
    include APIHelper

    socket_types =
      [ZMQ::REQ, ZMQ::REP, ZMQ::DEALER, ZMQ::ROUTER, ZMQ::PUB, ZMQ::SUB, ZMQ::PUSH, ZMQ::PULL, ZMQ::PAIR, ZMQ::XPUB, ZMQ::XSUB]

    context "when initializing" do
      before(:all) { @ctx = Context.new }
      after(:all) { @ctx.terminate }


      it "should raise an error for a nil context" do
        expect { Socket.new(FFI::Pointer.new(0), ZMQ::REQ) }.to raise_exception(ZMQ::ContextError)
      end

      it "works with a Context#pointer as the context_ptr" do
        expect do
          s = Socket.new(@ctx.pointer, ZMQ::REQ)
          s.close
        end.not_to raise_exception
      end

      it "works with a Context instance as the context_ptr" do
        expect do
          s = Socket.new(@ctx, ZMQ::SUB)
          s.close
        end.not_to raise_exception
      end


      socket_types.each do |socket_type|

        it "should not raise an error for a [#{ZMQ::SocketTypeNameMap[socket_type]}] socket type" do
          sock = nil
          expect { sock = Socket.new(@ctx.pointer, socket_type) }.not_to raise_error
          sock.close
        end
      end # each socket_type

      it "should set the :socket accessor to the raw socket allocated by libzmq" do
        socket = double('socket')
        allow(socket).to receive(:null?).and_return(false)
        expect(LibZMQ).to receive(:zmq_socket).and_return(socket)

        sock = Socket.new(@ctx.pointer, ZMQ::REQ)
        expect(sock.socket).to eq(socket)
      end

      it "should define a finalizer on this object" do
        expect(ObjectSpace).to receive(:define_finalizer).at_least(1)
        sock = Socket.new(@ctx.pointer, ZMQ::REQ)
        sock.close
      end

      unless jruby?
        it "should track pid in finalizer so subsequent fork will not segfault" do
          sock = Socket.new(@ctx.pointer, ZMQ::REQ)
          pid = fork { }
          Process.wait(pid)
          sock.close
        end
      end
    end # context initializing


    context "calling close" do
      before(:all) { @ctx = Context.new }
      after(:all) { @ctx.terminate }

      it "should call LibZMQ.close only once" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ
        raw_socket = sock.socket

        expect(LibZMQ).to receive(:close).with(raw_socket)
        sock.close
        sock.close
        LibZMQ.close raw_socket # *really close it otherwise the context will block indefinitely
      end
    end # context calling close



    context "identity=" do
      before(:all) { @ctx = Context.new }
      after(:all) { @ctx.terminate }

      it "fails to set identity for identities in excess of 255 bytes" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ

        sock.identity = ('a' * 256)
        expect(sock.identity).to eq('')
        sock.close
      end

      it "fails to set identity for identities of length 0" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ

        sock.identity = ''
        expect(sock.identity).to eq('')
        sock.close
      end

      it "sets the identity for identities of 1 byte" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ

        sock.identity = 'a'
        expect(sock.identity).to eq('a')
        sock.close
      end

      it "set the identity identities of 255 bytes" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ

        sock.identity = ('a' * 255)
        expect(sock.identity).to eq('a' * 255)
        sock.close
      end

      it "should convert numeric identities to strings" do
        sock = Socket.new @ctx.pointer, ZMQ::REQ

        sock.identity = 7
        expect(sock.identity).to eq('7')
        sock.close
      end
    end # context identity=



    socket_types.each do |socket_type|

      context "#setsockopt for a #{ZMQ::SocketTypeNameMap[socket_type]} socket" do
        before(:all) { @ctx = Context.new }
        after(:all) { @ctx.terminate }

        let(:socket) do
          Socket.new @ctx.pointer, socket_type
        end

        after(:each) do
          socket.close
        end


        context "using option ZMQ::IDENTITY" do
          it "should set the identity given any string under 255 characters" do
            length = 4
            (1..255).each do |length|
              identity = 'a' * length
              socket.setsockopt ZMQ::IDENTITY, identity

              array = []
              rc = socket.getsockopt(ZMQ::IDENTITY, array)
              expect(rc).to eq(0)
              expect(array[0]).to eq(identity)
            end
          end

          it "returns -1 given a string 256 characters or longer" do
            identity = 'a' * 256
            array = []
            rc = socket.setsockopt(ZMQ::IDENTITY, identity)
            expect(rc).to eq(-1)
          end
        end # context using option ZMQ::IDENTITY

        context "using option ZMQ::IPV4ONLY" do
          it "should enable use of IPV6 sockets when set to 0" do
            value = 0
            socket.setsockopt ZMQ::IPV4ONLY, value
            array = []
            rc = socket.getsockopt(ZMQ::IPV4ONLY, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(value)
          end

          it "should default to a value of 1" do
            value = 1
            array = []
            rc = socket.getsockopt(ZMQ::IPV4ONLY, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(value)
          end

          it "returns -1 given a negative value" do
            value = -1
            rc = socket.setsockopt ZMQ::IPV4ONLY, value
            expect(rc).to eq(-1)
          end

          it "returns -1 given a value > 1" do
            value = 2
            rc = socket.setsockopt ZMQ::IPV4ONLY, value
            expect(rc).to eq(-1)
          end
        end # context using option ZMQ::IPV4ONLY

        context "using option ZMQ::LAST_ENDPOINT" do
          it "should return last enpoint" do
            random_port = bind_to_random_tcp_port(socket, max_tries = 500)
            array = []
            rc = socket.getsockopt(ZMQ::LAST_ENDPOINT, array)
            expect(ZMQ::Util.resultcode_ok?(rc)).to eq(true)
            endpoint_regex = %r{\Atcp://(.*):(\d+)\0\z}
            expect(array[0]).to match(endpoint_regex)
            expect(Integer(array[0][endpoint_regex, 2])).to eq(random_port)
          end
        end

        context "using option ZMQ::SUBSCRIBE" do
          if ZMQ::SUB == socket_type
            it "returns 0 for a SUB socket" do
              rc = socket.setsockopt(ZMQ::SUBSCRIBE, "topic.string")
              expect(rc).to eq(0)
            end
          else
            it "returns -1 for non-SUB sockets" do
              rc = socket.setsockopt(ZMQ::SUBSCRIBE, "topic.string")
              expect(rc).to eq(-1)
            end
          end
        end # context using option ZMQ::SUBSCRIBE


        context "using option ZMQ::UNSUBSCRIBE" do
          if ZMQ::SUB == socket_type
            it "returns 0 given a topic string that was previously subscribed" do
              socket.setsockopt ZMQ::SUBSCRIBE, "topic.string"
              rc = socket.setsockopt(ZMQ::UNSUBSCRIBE, "topic.string")
              expect(rc).to eq(0)
            end

          else
            it "returns -1 for non-SUB sockets" do
              rc = socket.setsockopt(ZMQ::UNSUBSCRIBE, "topic.string")
              expect(rc).to eq(-1)
            end
          end
        end # context using option ZMQ::UNSUBSCRIBE


        context "using option ZMQ::AFFINITY" do
          it "should set the affinity value given a positive value" do
            affinity = 3
            socket.setsockopt ZMQ::AFFINITY, affinity
            array = []
            rc = socket.getsockopt(ZMQ::AFFINITY, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(affinity)
          end
        end # context using option ZMQ::AFFINITY


        context "using option ZMQ::RATE" do
          it "should set the multicast send rate given a positive value" do
            rate = 200
            socket.setsockopt ZMQ::RATE, rate
            array = []
            rc = socket.getsockopt(ZMQ::RATE, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(rate)
          end

          it "returns -1 given a negative value" do
            rate = -200
            rc = socket.setsockopt ZMQ::RATE, rate
            expect(rc).to eq(-1)
          end
        end # context using option ZMQ::RATE


        context "using option ZMQ::RECOVERY_IVL" do
          it "should set the multicast recovery buffer measured in seconds given a positive value" do
            rate = 200
            socket.setsockopt ZMQ::RECOVERY_IVL, rate
            array = []
            rc = socket.getsockopt(ZMQ::RECOVERY_IVL, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(rate)
          end

          it "returns -1 given a negative value" do
            rate = -200
            rc = socket.setsockopt ZMQ::RECOVERY_IVL, rate
            expect(rc).to eq(-1)
          end
        end # context using option ZMQ::RECOVERY_IVL


        context "using option ZMQ::SNDBUF" do
          it "should set the OS send buffer given a positive value" do
            size = 100
            socket.setsockopt ZMQ::SNDBUF, size
            array = []
            rc = socket.getsockopt(ZMQ::SNDBUF, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(size)
          end
        end # context using option ZMQ::SNDBUF


        context "using option ZMQ::RCVBUF" do
          it "should set the OS receive buffer given a positive value" do
            size = 100
            socket.setsockopt ZMQ::RCVBUF, size
            array = []
            rc = socket.getsockopt(ZMQ::RCVBUF, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(size)
          end
        end # context using option ZMQ::RCVBUF


        context "using option ZMQ::LINGER" do
          it "should set the socket message linger option measured in milliseconds given a positive value" do
            value = 200
            socket.setsockopt ZMQ::LINGER, value
            array = []
            rc = socket.getsockopt(ZMQ::LINGER, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(value)
          end

          it "should set the socket message linger option to 0 for dropping packets" do
            value = 0
            socket.setsockopt ZMQ::LINGER, value
            array = []
            rc = socket.getsockopt(ZMQ::LINGER, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(value)
          end

            it "should default to a value of 0" do
              value = [SUB, XSUB].include?(socket_type) ? 0 : -1
              array = []
              rc = socket.getsockopt(ZMQ::LINGER, array)
              expect(rc).to eq(0)
              expect(array[0]).to eq(value)
            end
        end # context using option ZMQ::LINGER


        context "using option ZMQ::RECONNECT_IVL" do
          it "should set the time interval for reconnecting disconnected sockets measured in milliseconds given a positive value" do
            value = 200
            socket.setsockopt ZMQ::RECONNECT_IVL, value
            array = []
            rc = socket.getsockopt(ZMQ::RECONNECT_IVL, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(value)
          end

          it "should default to a value of 100" do
            value = 100
            array = []
            rc = socket.getsockopt(ZMQ::RECONNECT_IVL, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(value)
          end
        end # context using option ZMQ::RECONNECT_IVL


        context "using option ZMQ::BACKLOG" do
          it "should set the maximum number of pending socket connections given a positive value" do
            value = 200
            rc = socket.setsockopt ZMQ::BACKLOG, value
            expect(rc).to eq(0)
            array = []
            rc = socket.getsockopt(ZMQ::BACKLOG, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(value)
          end

          it "should default to a value of 100" do
            value = 100
            array = []
            rc = socket.getsockopt(ZMQ::BACKLOG, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(value)
          end
        end # context using option ZMQ::BACKLOG

      end # context #setsockopt


      context "#getsockopt for a #{ZMQ::SocketTypeNameMap[socket_type]} socket" do
        before(:all) { @ctx = Context.new }
        after(:all) { @ctx.terminate }

        let(:socket) do
          Socket.new @ctx.pointer, socket_type
        end

        after(:each) do
          socket.close
        end

        if RUBY_PLATFORM =~ /linux|darwin/
          # this spec doesn't work on Windows; hints welcome

          context "using option ZMQ::FD" do
            it "should return an FD as a positive integer" do
              array = []
              rc = socket.getsockopt(ZMQ::FD, array)
              expect(rc).to eq(0)
              expect(array[0]).to be > 0
            end

            it "returns a valid FD that is accepted by the system poll() function" do
              # Use FFI to wrap the C library function +poll+ so that we can execute it
              # on the 0mq file descriptor. If it returns 0, then it succeeded and the FD
              # is valid!
              module LibSocket
                extend FFI::Library
                # figures out the correct libc for each platform including Windows
                library = ffi_lib(FFI::Library::LIBC).first

                find_type(:nfds_t) rescue typedef(:uint32, :nfds_t)

                attach_function :poll, [:pointer, :nfds_t, :int], :int

                class PollFD < FFI::Struct
                  layout :fd,    :int,
                    :events, :short,
                    :revents, :short
                end
              end # module LibSocket

              array = []
              rc = socket.getsockopt(ZMQ::FD, array)
              expect(rc).to eq(0)
              fd = array[0]

              # setup the BSD poll_fd struct
              pollfd = LibSocket::PollFD.new
              pollfd[:fd] = fd
              pollfd[:events] = 0
              pollfd[:revents] = 0

              rc = LibSocket.poll(pollfd, 1, 0)
              expect(rc).to eq(0)
            end
          end

        end # posix platform

        context "using option ZMQ::EVENTS" do
          it "should return a mask of events as a Fixnum" do
            array = []
            rc = socket.getsockopt(ZMQ::EVENTS, array)
            expect(rc).to eq(0)
            expect(array[0]).to be_a(Fixnum)
          end
        end

        context "using option ZMQ::TYPE" do
          it "should return the socket type" do
            array = []
            rc = socket.getsockopt(ZMQ::TYPE, array)
            expect(rc).to eq(0)
            expect(array[0]).to eq(socket_type)
          end
        end
      end # context #getsockopt

    end # each socket_type


    describe "Mapping socket EVENTS to POLLIN and POLLOUT" do
      include APIHelper

      shared_examples_for "pubsub sockets where" do
        it "SUB socket that received a message always has POLLIN set" do
          events = []
          rc = @sub.getsockopt(ZMQ::EVENTS, events)
          expect(rc).to eq(0)
          expect(events[0]).to eq ZMQ::POLLIN
        end

        it "PUB socket always has POLLOUT set" do
          events = []
          rc = @pub.getsockopt(ZMQ::EVENTS, events)
          expect(rc).to eq(0)
          expect(events[0]).to eq ZMQ::POLLOUT
        end

        it "PUB socket never has POLLIN set" do
          events = []
          rc = @pub.getsockopt(ZMQ::EVENTS, events)
          expect(rc).to eq(0)
          expect(events[0]).not_to eq ZMQ::POLLIN
        end

        it "SUB socket never has POLLOUT set" do
          events = []
          rc = @sub.getsockopt(ZMQ::EVENTS, events)
          expect(rc).to eq(0)
          expect(events[0]).not_to eq ZMQ::POLLOUT
        end
      end # shared example for pubsub

      context "when SUB binds and PUB connects" do

        before(:each) do
          @ctx = Context.new
          poller_setup

          endpoint = "inproc://socket_test"
          @sub = @ctx.socket ZMQ::SUB
          rc = @sub.setsockopt ZMQ::SUBSCRIBE, ''
          expect(rc).to eq(0)

          @pub = @ctx.socket ZMQ::PUB
          @sub.bind(endpoint)
          connect_to_inproc(@pub, endpoint)

          @pub.send_string('test')
        end

        #it_behaves_like "pubsub sockets where" # see Jira LIBZMQ-270
      end # context SUB binds PUB connects

      context "when SUB connects and PUB binds" do

        before(:each) do
          @ctx = Context.new
          poller_setup

          endpoint = "inproc://socket_test"
          @sub = @ctx.socket ZMQ::SUB
          rc = @sub.setsockopt ZMQ::SUBSCRIBE, ''

          @pub = @ctx.socket ZMQ::PUB
          @pub.bind(endpoint)
          connect_to_inproc(@sub, endpoint)

          poll_it_for_read(@sub) do
            rc = @pub.send_string('test')
          end
        end

        it_behaves_like "pubsub sockets where"
      end # context SUB binds PUB connects


      after(:each) do
        @sub.close
        @pub.close
        # must call close on *every* socket before calling terminate otherwise it blocks indefinitely
        @ctx.terminate
      end

    end # describe 'events mapping to pollin and pollout'

  end # describe Socket


end # module ZMQ

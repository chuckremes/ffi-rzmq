require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rzmq')

# This example shows the basics of a CURVE-secured REP/REQ setup between
# a Server and Client. This is the minimal required setup for authenticating
# a connection between a Client and a Server. For validating the Client's authentication
# once the initial connection has succeeded, you'll need a ZAP handler on the Server.

# Build the Server's keys
server_public_key, server_private_key = ZMQ::Util.curve_keypair

# Build the Client's keys
client_public_key, client_private_key = ZMQ::Util.curve_keypair

context = ZMQ::Context.new
bind_point = "tcp://127.0.0.1:4455"

##
# Configure the Server
##
server = context.socket ZMQ::REP

server.setsockopt(ZMQ::CURVE_SERVER, 1)
server.setsockopt(ZMQ::CURVE_SECRETKEY, server_private_key)

server.bind(bind_point)

##
# Configure the Client to talk to the Server
##
client = context.socket ZMQ::REQ

client.setsockopt(ZMQ::CURVE_SERVERKEY, server_public_key)
client.setsockopt(ZMQ::CURVE_PUBLICKEY, client_public_key)
client.setsockopt(ZMQ::CURVE_SECRETKEY, client_private_key)

client.connect(bind_point)

##
# Show that communication still works
##

client_message = "Hello Server!"
server_response = "Hello Client!"

puts "Client sending: #{client_message}"
client.send_string client_message

server.recv_string(server_message = '')
puts "Server received: #{server_message}, replying with #{server_response}"

server.send_string(server_response)

client.recv_string(response = '')
puts "Client has received: #{response}"

puts "Finished"

client.close
server.close
context.terminate

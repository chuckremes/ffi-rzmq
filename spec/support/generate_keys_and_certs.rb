# Copied from Debian:
# https://salsa.debian.org/ruby-team/ruby-ffi-rzmq/commit/15ad9dd6f4c3358acbd7db2c7e288aae2d5efcf8
#
# Script should be run from the spec/support directory.
#

require "openssl"

key = OpenSSL::PKey::RSA.new 4096

open 'private_key.pem', 'w' do |io| io.write key.to_pem end
open 'public_key.pem', 'w' do |io| io.write key.public_key.to_pem end


name = OpenSSL::X509::Name.parse 'CN=nobody/DC=example'

cert = OpenSSL::X509::Certificate.new
cert.version = 2
cert.serial = 0
cert.not_before = Time.now
cert.not_after = Time.now + 3600*24*365*10

cert.public_key = key.public_key
cert.subject = name
cert.issuer = name

extension_factory = OpenSSL::X509::ExtensionFactory.new
extension_factory.subject_certificate = cert
extension_factory.issuer_certificate = cert

cert.add_extension \
  extension_factory.create_extension('subjectKeyIdentifier', 'hash')
cert.sign key, OpenSSL::Digest::SHA1.new
open 'ca.pem', 'w' do |io|
  io.write cert.to_pem
end

require 'fileutils'

FileUtils.cp 'ca.pem',         'test.crt'
FileUtils.cp 'private_key.pem', 'test.key'

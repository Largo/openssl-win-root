# frozen_string_literal: true

# Child process for test_inject.rb: prints key=value lines.
require "openssl"

ruby_defaults = OpenSSL::X509::Store.new.tap(&:set_default_paths)
require "openssl/win/root/certificates"
root = OpenSSL::Win::Root.certificates.find { |c| c.subject == c.issuer && !ruby_defaults.verify(c) }
default_store = OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE

puts "certificates=#{OpenSSL::Win::Root.certificates.size}"
puts "default_store_before=#{root ? default_store.verify(root) : 'n/a'}"
require "openssl/win/root"
puts "injected=#{OpenSSL::Win::Root.injected?}"
puts "default_store_after=#{root ? default_store.verify(root) : 'n/a'}"
puts "new_store_after=#{root ? OpenSSL::X509::Store.new.tap(&:set_default_paths).verify(root) : 'n/a'}"
puts "inject_again=#{OpenSSL::Win::Root.inject!}"

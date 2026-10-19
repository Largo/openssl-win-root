# frozen_string_literal: true

# Make Ruby's OpenSSL trust the certificates Windows trusts.
# Does nothing on other platforms. For the same API without the automatic
# injection, require "openssl/win/root/certificates" instead.
require_relative "root/certificates"

OpenSSL::Win::Root.inject!

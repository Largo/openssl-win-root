# frozen_string_literal: true

require "minitest/autorun"
require "openssl/win/root/certificates"

module TestHelper
  Root = OpenSSL::Win::Root

  def self_signed(certs)
    certs.select { |c| c.subject == c.issuer }
  end

  # A self-signed root only Windows trusts, not Ruby's own CA list.
  def windows_only_root
    ruby_defaults = OpenSSL::X509::Store.new.tap(&:set_default_paths)
    self_signed(Root.certificates).find { |c| !ruby_defaults.verify(c) }
  end
end

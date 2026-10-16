# frozen_string_literal: true

require_relative "test_helper"

class TestCertificates < Minitest::Test
  include TestHelper

  def setup
    skip "Windows only" unless Root.available?
  end

  def test_reads_certificates
    certs = Root.certificates
    assert_nil Root.last_error
    refute_empty self_signed(certs), "expected trusted roots"
    assert(certs.all? { |c| c.is_a?(OpenSSL::X509::Certificate) })
    assert_equal certs.size, certs.uniq(&:to_der).size, "duplicates"
    assert(certs.none? { |c| c.not_after < Time.now }, "expired certificates")
  end

  def test_cached_and_frozen
    assert_same Root.certificates, Root.certificates
    assert_predicate Root.certificates, :frozen?
  end

  def test_reload_reads_again
    before = Root.certificates
    Root.reload!
    refute_same before, Root.certificates
    assert_equal before.map(&:to_der), Root.certificates.map(&:to_der)
  end

  def test_add_to_lets_an_empty_store_verify_windows_roots
    root = self_signed(Root.certificates).first
    store = OpenSSL::X509::Store.new
    refute store.verify(root)

    assert_equal Root.certificates.size, Root.add_to(store)
    assert store.verify(root), store.error_string
  end

  def test_add_to_twice_skips_duplicates
    store = OpenSSL::X509::Store.new
    Root.add_to(store)
    assert_operator Root.add_to(store), :<=, Root.certificates.size
  end

  def test_unknown_store_yields_nothing
    require "openssl/win/root/crypt32" # loaded lazily by Root.certificates
    assert_equal 0, Root::Crypt32.each_der(:local_machine, "NoSuchStore#{rand(1 << 30)}").count
  end

  def test_to_pem_round_trips
    pem = Root.to_pem
    assert_equal Root.certificates.size, pem.scan("-----BEGIN CERTIFICATE-----").size
  end

  def test_https_with_windows_certificates_only
    skip "set OFFLINE=1 to skip network tests" if ENV["OFFLINE"]
    require "net/http"

    store = OpenSSL::X509::Store.new
    Root.add_to(store)
    http = Net::HTTP.new("github.com", 443)
    http.use_ssl = true
    http.cert_store = store
    assert_kind_of Net::HTTPResponse, http.start { http.head("/") }
  end
end

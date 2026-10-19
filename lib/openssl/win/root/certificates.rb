# frozen_string_literal: true

require "openssl"
require_relative "version"

module OpenSSL
  module Win
    # Feeds the certificates Windows trusts to Ruby's OpenSSL.
    #
    # Requiring this file has no side effects; +require "openssl/win/root"+
    # additionally calls #inject!. Everything is kept in memory, nothing is
    # written to disk. On other platforms the certificate list is empty.
    module Root
      # Trust anchors.
      TRUSTED_STORES = %w[ROOT AuthRoot].freeze
      # Intermediate CAs, so chains verify even when a server omits its
      # intermediates. Self-signed entries here are ignored: Windows does not
      # trust a root just because it sits in the CA store, so neither do we.
      INTERMEDIATE_STORES = %w[CA].freeze
      # Certificates an administrator has explicitly distrusted.
      DISALLOWED_STORES = %w[Disallowed].freeze
      LOCATIONS = %i[local_machine current_user].freeze

      @mutex = Mutex.new
      @certificates = nil
      @last_error = nil
      @injected = false

      class << self
        # Why the last read of the Windows stores failed, or nil.
        attr_reader :last_error

        def available?
          Gem.win_platform?
        end

        # The certificates from the Windows stores, read once and cached.
        def certificates
          @mutex.synchronize { @certificates ||= read_certificates.freeze }
        end

        # Forget the cached certificates; the next call reads the stores again.
        # Stores that already received certificates keep them.
        def reload!
          @mutex.synchronize { @certificates = nil }
          self
        end

        # Adds the Windows certificates to +store+ (an OpenSSL::X509::Store).
        # Returns the number of certificates added.
        def add_to(store)
          certificates.count do |cert|
            store.add_cert(cert)
            true
          rescue OpenSSL::X509::StoreError
            false # already present, e.g. the same root in Ruby's own CA file
          end
        end

        # Makes Ruby's default certificate stores trust the Windows certificates:
        # the one Net::HTTP & co. use when given no cert_store/ca_file
        # (SSLContext::DEFAULT_CERT_STORE), and every store that calls
        # X509::Store#set_default_paths from now on. Safe to call repeatedly.
        def inject!
          return false unless available?

          @mutex.synchronize do
            return false if @injected

            @injected = true
          end
          OpenSSL::X509::Store.prepend(DefaultPaths)
          add_to(OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE)
          true
        end

        def injected?
          @injected
        end

        # All certificates as one PEM bundle, e.g. for SSL_CERT_FILE of a
        # non-Ruby tool: File.write("windows.pem", OpenSSL::Win::Root.to_pem)
        def to_pem
          certificates.map(&:to_pem).join
        end

        private

        def read_certificates
          @last_error = nil
          return [] unless available?

          require_relative "crypt32"
          disallowed = der_set(DISALLOWED_STORES).map { |der| fingerprint(der) }
          trusted = der_set(TRUSTED_STORES).map { |der| parse(der) }
          intermediate = der_set(INTERMEDIATE_STORES).map { |der| parse(der) }
                                                     .reject { |cert| cert && self_signed?(cert) }
          now = Time.now
          (trusted + intermediate).compact.uniq(&:to_der).reject do |cert|
            cert.not_after < now || disallowed.include?(fingerprint(cert.to_der))
          end
        rescue LoadError, StandardError => e
          @last_error = e
          []
        end

        def der_set(names)
          LOCATIONS.product(names).flat_map { |location, name| Crypt32.each_der(location, name).to_a }.uniq
        end

        def parse(der)
          OpenSSL::X509::Certificate.new(der)
        rescue OpenSSL::X509::CertificateError
          nil # Windows stores can hold entries OpenSSL cannot parse
        end

        def fingerprint(der)
          OpenSSL::Digest::SHA256.digest(der)
        end

        def self_signed?(cert)
          cert.subject == cert.issuer
        end
      end

      # Prepended to OpenSSL::X509::Store by inject!.
      module DefaultPaths
        def set_default_paths
          result = super
          # Module state is not shareable; stores built inside other Ractors
          # get Ruby's defaults only.
          Root.add_to(self) if !defined?(Ractor) || !Ractor.respond_to?(:main) || Ractor.current == Ractor.main
          result
        end
      end
    end
  end
end

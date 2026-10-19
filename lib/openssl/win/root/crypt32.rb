# frozen_string_literal: true

require "fiddle/import"

module OpenSSL
  module Win
    module Root
      # Minimal binding to crypt32.dll: enumerate the DER certificates of a
      # Windows system certificate store. Based on Puppet::Util::Windows::RootCerts.
      module Crypt32
        extend Fiddle::Importer
        dlload "crypt32"

        CERT_STORE_PROV_SYSTEM_W = 10
        CERT_STORE_OPEN_EXISTING_FLAG = 0x0000_4000
        CERT_STORE_READONLY_FLAG = 0x0000_8000

        LOCATIONS = {
          current_user: 0x0001_0000,  # CERT_SYSTEM_STORE_CURRENT_USER
          local_machine: 0x0002_0000, # CERT_SYSTEM_STORE_LOCAL_MACHINE
        }.freeze

        extern "void* CertOpenStore(void*, unsigned int, void*, unsigned int, void*)", :stdcall
        extern "void* CertEnumCertificatesInStore(void*, void*)", :stdcall
        extern "int CertCloseStore(void*, unsigned int)", :stdcall

        CertContext = struct [
          "unsigned int dwCertEncodingType",
          "unsigned char* pbCertEncoded",
          "unsigned int cbCertEncoded",
          "void* pCertInfo",
          "void* hCertStore",
        ]

        # Yields the DER bytes of every certificate in +location+\+name+
        # (e.g. :local_machine, "ROOT"). A store that does not exist yields nothing.
        def self.each_der(location, name)
          return enum_for(__method__, location, name) unless block_given?

          flags = LOCATIONS.fetch(location) | CERT_STORE_OPEN_EXISTING_FLAG | CERT_STORE_READONLY_FLAG
          wide_name = "#{name}\0".encode(Encoding::UTF_16LE)
          store = CertOpenStore(CERT_STORE_PROV_SYSTEM_W, 0, nil, flags, wide_name)
          return if store.null?

          begin
            ctx = Fiddle::Pointer.new(0)
            # Each call frees the previous context, so nothing is leaked.
            until (ctx = CertEnumCertificatesInStore(store, ctx)).null?
              cert = CertContext.new(ctx)
              yield cert.pbCertEncoded[0, cert.cbCertEncoded]
            end
          ensure
            CertCloseStore(store, 0)
          end
        end
      end
    end
  end
end

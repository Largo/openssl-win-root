# Changelog

## 2.0.0

Rewritten to keep everything in memory. Breaking changes are marked **(breaking)**.

- No files are written anymore. 1.x wrote every root certificate as a PEM file into a
  `pem` folder next to the gem's `Gemfile`, from a background thread. That failed in
  read-only or packaged installs (e.g. a Windows service under `C:\Program Files`), could
  loop forever when no `Gemfile` was found, and the first HTTPS request could run before
  the files existed. **(breaking)** `OpenSSL::Win::Root.path`, `.save`, `.inject`,
  `.go!` and the `SSL_CERT_DIR` it set are gone; use `.to_pem` to export a bundle.
- Certificates are read synchronously when the gem is required and added directly to
  `OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE`.
- Every `OpenSSL::X509::Store#set_default_paths` call now also adds the Windows
  certificates, so stores built by Faraday, HTTPClient etc. trust them too.
- Reads `ROOT` and `AuthRoot` of both the local machine and the current user, plus
  intermediate CAs from the `CA` stores. Self-signed certificates in `CA`, expired
  certificates and certificates in `Disallowed` are skipped. 1.x read only `ROOT` as the
  current user sees it (which includes the machine roots), without `AuthRoot` or `CA`.
- New API: `certificates`, `add_to(store)`, `inject!`, `injected?`, `reload!`,
  `to_pem`, `last_error`. `require "openssl/win/root/certificates"` loads it without
  injecting anything.
- A failure to read the Windows store no longer raises; the gem does nothing and
  `last_error` says why.
- `fiddle` is declared as a dependency (it became a bundled gem in Ruby 3.5/4.0).
- Requires Ruby 2.7 or newer. CI moved from AppVeyor to GitHub Actions (Ruby 2.7–4.0).
- `gem build` works again: the gemspec no longer defines `OpenSSL` before openssl is loaded.

## 1.1.2

- `File.exists?` → `File.exist?` for Ruby 3.2.

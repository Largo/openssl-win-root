# OpenSSL::Win::Root

[![test](https://github.com/Largo/openssl-win-root/actions/workflows/test.yml/badge.svg)](https://github.com/Largo/openssl-win-root/actions/workflows/test.yml)
[![Gem Version](https://badge.fury.io/rb/openssl-win-root.svg)](https://rubygems.org/gems/openssl-win-root)

Make Ruby's OpenSSL trust the certificates that Windows trusts.

## Why

OpenSSL does not know about the Windows certificate store. Ruby on Windows
(RubyInstaller) ships its own copy of the Mozilla CA list instead, which is frozen at
the time that Ruby was built and knows nothing about certificates added on the machine.
So a server that every browser on the machine accepts can still fail in Ruby with
`certificate verify failed`, typically when

- the company's internal CA is rolled out by group policy,
- an administrator imported a self-signed certificate as a trusted root,
- a TLS-inspecting proxy re-signs traffic with its own root, or
- a newer public root is missing from Ruby's bundled list.

This gem reads the certificates from the Windows store through `crypt32.dll` and adds
them to OpenSSL, in memory. No network access, no files written. On other platforms it
does nothing.

## Installation

```ruby
# Gemfile
gem "openssl-win-root" # safe everywhere: does nothing off Windows
```

Or `gem install openssl-win-root`.

## Usage

```ruby
require "openssl/win/root"
```

That is all. With `Bundler.require` (e.g. Rails) not even that. From then on

- `OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE`, which `Net::HTTP`, `open-uri` and
  anything else that gives no `cert_store`/`ca_file` uses, contains the Windows
  certificates, and
- every `OpenSSL::X509::Store#set_default_paths` call adds them too, so stores that
  libraries such as Faraday or HTTPClient build themselves trust them as well.

Ruby's own CA list stays in place; the Windows certificates are added to it.

### Without global changes

```ruby
require "openssl/win/root/certificates" # loads the API, injects nothing

store = OpenSSL::X509::Store.new
store.set_default_paths
OpenSSL::Win::Root.add_to(store)    # => number of certificates added

OpenSSL::Win::Root.certificates     # => [#<OpenSSL::X509::Certificate ...>, ...]
OpenSSL::Win::Root.inject!          # what require "openssl/win/root" does
OpenSSL::Win::Root.reload!          # read the store again on next use
OpenSSL::Win::Root.last_error       # why reading the store failed, or nil
```

### For other programs

```ruby
File.write("windows-roots.pem", OpenSSL::Win::Root.to_pem)
```

and point `SSL_CERT_FILE`, `curl --cacert` or `openssl -CAfile` at that file.

## Which certificates

| Store                | Location                       | Used as                                  |
| -------------------- | ------------------------------ | ---------------------------------------- |
| `ROOT`, `AuthRoot`   | local machine and current user | trust anchors                            |
| `CA`                 | local machine and current user | intermediates for chain building only    |
| `Disallowed`         | local machine and current user | excluded                                 |

Self-signed certificates in `CA` are ignored (Windows does not trust them either), as
are expired certificates.

The certificates are read once, when the gem is required (about 80 ms, most of it
loading `fiddle`). Certificates added to Windows later are picked up after `reload!`
by stores created afterwards, or on the next start.

Stores created inside a non-main Ractor get Ruby's default certificates only.

## Caution

Windows fetches some third-party roots (`AuthRoot`) only when it first needs them. If a
site works in Edge but not in Ruby, opening it once in Edge (or with `WinHttpRequest`)
usually makes Windows download the missing root, after which this gem sees it.

## Upgrading from 1.x

1.x wrote the certificates as PEM files into a `pem` folder inside the gem and set
`SSL_CERT_DIR`. 2.0 writes nothing; `OpenSSL::Win::Root.path` and `.save` are gone, use
`to_pem` if another program needs the certificates. See [CHANGELOG.md](CHANGELOG.md).

## See also

- [win-ca](https://github.com/ukoloff/win-ca), the same for Node.js, by the original
  author of this gem

## License

MIT, see [LICENSE.txt](LICENSE.txt).

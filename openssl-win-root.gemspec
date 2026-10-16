# frozen_string_literal: true

# Not required: defining an empty OpenSSL module here makes RubyGems think
# openssl is already loaded, and `gem build` then fails on OpenSSL::Digest.
version = File.read(File.expand_path("lib/openssl/win/root/version.rb", __dir__))[/VERSION = "(.+)"/, 1]

Gem::Specification.new do |spec|
  spec.name          = "openssl-win-root"
  spec.version       = version
  spec.authors       = ["Stas Ukolov", "Largo"]
  spec.summary       = "Make Ruby's OpenSSL trust the certificates in the Windows certificate store"
  spec.description   = <<~DESC
    Reads the trusted root and intermediate certificates from the Windows certificate
    store (local machine and current user) and adds them to Ruby's OpenSSL, in memory.
    Certificates rolled out by group policy or imported by an administrator work
    without copying them anywhere. Does nothing on other platforms.
  DESC
  spec.homepage      = "https://github.com/Largo/openssl-win-root"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true",
  }

  spec.files         = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  # Calls crypt32.dll. A default gem up to Ruby 3.4 and a bundled gem from 3.5 on,
  # so it is already installed either way; declared so Bundler loads it.
  spec.add_dependency "fiddle", ">= 1.0"
end

# frozen_string_literal: true

require_relative "test_helper"
require "rbconfig"

# Injection changes process-wide state, so it runs in a child process.
class TestInject < Minitest::Test
  include TestHelper

  CHECK = File.expand_path("fixtures/inject_check.rb", __dir__)
  LIB = File.expand_path("../lib", __dir__)

  def run_check
    out = IO.popen([RbConfig.ruby, "-I", LIB, CHECK], err: %i[child out], &:read)
    assert $?.success?, out
    out.lines.to_h { |l| l.chomp.split("=", 2) }
  end

  def test_require_injects_into_default_stores
    skip "Windows only" unless Root.available?
    skip "every Windows root is also in Ruby's CA list" unless windows_only_root

    result = run_check
    assert_equal "false", result["default_store_before"]
    assert_equal "true", result["injected"]
    assert_equal "true", result["default_store_after"]
    assert_equal "true", result["new_store_after"]
    assert_equal "false", result["inject_again"]
  end

  def test_noop_off_windows
    skip "non-Windows only" if Root.available?

    result = run_check
    assert_equal "false", result["injected"]
    assert_equal "0", result["certificates"]
  end
end

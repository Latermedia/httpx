# frozen_string_literal: true

require_relative "test_helper"
require "httpx/plugins/proxy"

class ProxyTest < Minitest::Test
  include HTTPHelpers
  include HTTPX

  def test_parameters_equality
    params = parameters(username: "user", password: "pass")
    assert params == parameters(username: "user", password: "pass")
    assert params != parameters(username: "user2", password: "pass")
    assert params != parameters
    assert params == URI.parse("http://user:pass@proxy")
    assert params == "http://user:pass@proxy"
    assert params != "bamalam"
    assert params != 1
  end

  %w[basic digest ntlm].each do |auth_method|
    define_method :"test_proxy_factory_#{auth_method}" do
      basic_proxy_opts = HTTPX.plugin(:proxy).__send__(:"with_proxy_#{auth_method}_auth", username: "user",
                                                                                          password: "pass").instance_variable_get(:@options)
      proxy = basic_proxy_opts.proxy
      assert proxy.username == "user"
      assert proxy.password == "pass"
      assert proxy.scheme == auth_method
    end
  end

  def test_proxy_unsupported_scheme
    res = HTTPX.plugin(:proxy).with_proxy(uri: "https://proxy:123").get("http://smth.com")
    verify_error_response(res, HTTPX::HTTPProxyError)
    verify_error_response(res, "https: unsupported proxy protocol")
  end

  private

  def parameters(uri: "http://proxy", **args)
    Plugins::Proxy::Parameters.new(uri: uri, **args)
  end
end

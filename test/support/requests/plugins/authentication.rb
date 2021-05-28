# frozen_string_literal: true

module Requests
  module Plugins
    module Authentication
      # Basic Auth

      def test_plugin_basic_authentication
        no_auth_response = HTTPX.get(basic_auth_uri)
        verify_status(no_auth_response, 401)
        verify_header(no_auth_response.headers, "www-authenticate", "Basic realm=\"Fake Realm\"")
        no_auth_response.close

        session = HTTPX.plugin(:basic_authentication)
        response = session.basic_authentication(user, pass).get(basic_auth_uri)
        verify_status(response, 200)
        body = json_body(response)
        verify_header(body, "authenticated", true)
        verify_header(body, "user", user)

        invalid_response = session.basic_authentication(user, "fake").get(basic_auth_uri)
        verify_status(invalid_response, 401)
      end

      # Digest

      def test_plugin_digest_authentication
        session = HTTPX.plugin(:digest_authentication).with_headers("cookie" => "fake=fake_value")
        response = session.digest_authentication(user, pass).get(digest_auth_uri)
        verify_status(response, 200)
        body = json_body(response)
        verify_header(body, "authenticated", true)
        verify_header(body, "user", user)
      end

      %w[SHA1 SHA2 SHA256 SHA384 SHA512 RMD160].each do |alg|
        define_method "test_plugin_digest_authentication_#{alg}" do
          session = HTTPX.plugin(:digest_authentication).with_headers("cookie" => "fake=fake_value")
          response = session.digest_authentication(user, pass).get("#{digest_auth_uri}/#{alg}")
          verify_status(response, 200)
          body = json_body(response)
          verify_header(body, "authenticated", true)
          verify_header(body, "user", user)
        end
      end

      # NTLM

      def test_plugin_ntlm_authentication
        return if origin.start_with?("https")

        server = NTLMServer.new
        th = Thread.new { server.start }
        begin
          uri = "#{server.origin}/"
          HTTPX.plugin(SessionWithPool).plugin(:ntlm_authentication).wrap do |http|
            # skip unless NTLM
            no_auth_response = http.get(uri)
            verify_status(no_auth_response, 401)
            no_auth_response.close

            response = http.ntlm_authentication("user", "password").get(uri)
            verify_status(response, 200)

            # invalid_response = http.ntlm_authentication("user", "fake").get(uri)
            # verify_status(invalid_response, 401)
          end
        ensure
          server.shutdown
          th.join
        end
      end

      private

      def basic_auth_uri
        build_uri("/basic-auth/#{user}/#{pass}")
      end

      def digest_auth_uri(qop = "auth")
        build_uri("/digest-auth/#{qop}/#{user}/#{pass}")
      end

      def user
        "user"
      end

      def pass
        "pass"
      end
    end
  end
end

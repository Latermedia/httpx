# frozen_string_literal: true

module HTTPX
  module Plugins
    module BasicAuthentication
      def self.load_dependencies(klass, *)
        require "base64"
        klass.plugin(:authentication)
      end

      module InstanceMethods
        def basic_authentication(user, password)
          authentication("Basic #{Base64.strict_encode64("#{user}:#{password}")}")
        end
        alias :basic_auth :basic_authentication
      end
    end
    register_plugin :basic_authentication, BasicAuthentication
  end
end


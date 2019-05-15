# frozen_string_literal: true

module HTTPX
  module Plugins
    #
    # This plugin adds support for retrying requests when certain errors happen.
    #
    module Retries
      MAX_RETRIES = 3
      # TODO: pass max_retries in a configure/load block

      IDEMPOTENT_METHODS = %i[get options head put delete].freeze
      RETRYABLE_ERRORS = [IOError,
                          EOFError,
                          Errno::ECONNRESET,
                          Errno::ECONNABORTED,
                          Errno::EPIPE,
                          (OpenSSL::SSL::SSLError if defined?(OpenSSL)),
                          TimeoutError,
                          Parser::Error,
                          Errno::EINVAL,
                          Errno::ETIMEDOUT].freeze

      def self.extra_options(options)
        Class.new(options.class) do
          def_option(:max_retries) do |num|
            num = Integer(num)
            raise Error, ":max_retries must be positive" unless num.positive?

            num
          end

          def_option(:retry_change_requests)
        end.new(options)
      end

      module InstanceMethods
        def max_retries(n)
          branch(default_options.with_max_retries(n.to_i))
        end

        private

        def fetch_response(request, connections, options)
          response = super
          if response.is_a?(ErrorResponse) &&
             request.retries.positive? &&
             __repeatable_request?(request, options) &&
             __retryable_error?(response.error)
            request.retries -= 1
            log { "failed to get response, #{request.retries} tries to go..." }
            request.transition(:idle)
            connection = find_connection(request, connections, options)
            connection.send(request)
            return
          end
          response
        end

        def __repeatable_request?(request, options)
          IDEMPOTENT_METHODS.include?(request.verb) || options.retry_change_requests
        end

        def __retryable_error?(ex)
          RETRYABLE_ERRORS.any? { |klass| ex.is_a?(klass) }
        end
      end

      module RequestMethods
        attr_accessor :retries

        def initialize(*args)
          super
          @retries = @options.max_retries || MAX_RETRIES
        end
      end
    end
    register_plugin :retries, Retries
  end
end

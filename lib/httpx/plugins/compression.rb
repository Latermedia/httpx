# frozen_string_literal: true

module HTTPX
  module Plugins
    #
    # This plugin adds compression support. Namely it:
    #
    # * Compresses the request body when passed a supported "Content-Encoding" mime-type;
    # * Decompresses the response body from a supported "Content-Encoding" mime-type;
    #
    # It supports both *gzip* and *deflate*.
    #
    # https://gitlab.com/honeyryderchuck/httpx/wikis/Compression
    #
    module Compression
      extend Registry

      class << self
        def load_dependencies(klass)
          klass.plugin(:"compression/gzip")
          klass.plugin(:"compression/deflate")
        end

        def extra_options(options)
          Class.new(options.class) do
            def_option(:compression_threshold_size) do |bytes|
              bytes = Integer(bytes)
              raise Error, ":expect_threshold_size must be positive" unless bytes.positive?

              bytes
            end
          end.new(options).merge(headers: { "accept-encoding" => Compression.registry.keys })
        end
      end

      module RequestMethods
        def initialize(*)
          super
          # forego compression in the Range cases
          @headers.delete("accept-encoding") if @headers.key?("range")
        end
      end

      module RequestBodyMethods
        def initialize(*, options)
          super
          return if @body.nil?

          threshold = options.compression_threshold_size
          return if threshold && !unbounded_body? && @body.bytesize < threshold

          @headers.get("content-encoding").each do |encoding|
            next if encoding == "identity"

            @body = Encoder.new(@body, Compression.registry(encoding).deflater)
          end
          @headers["content-length"] = @body.bytesize unless chunked?
        end
      end

      module ResponseBodyMethods
        attr_reader :encodings

        def initialize(*, **)
          @encodings = []

          super

          return unless @headers.key?("content-encoding")

          # remove encodings that we are able to decode
          @headers["content-encoding"] = @headers.get("content-encoding") - @encodings

          compressed_length = if @headers.key?("content-length")
            @headers["content-length"].to_i
          else
            Float::INFINITY
          end

          @_inflaters = @headers.get("content-encoding").map do |encoding|
            next if encoding == "identity"

            inflater = Compression.registry(encoding).inflater(compressed_length)
            # do not uncompress if there is no decoder available. In fact, we can't reliably
            # continue decompressing beyond that, so ignore.
            break unless inflater

            @encodings << encoding
            inflater
          end.compact

          # this can happen if the only declared encoding is "identity"
          remove_instance_variable(:@_inflaters) if @_inflaters.empty?
        end

        def write(chunk)
          return super unless defined?(@_inflaters) && !chunk.empty?

          chunk = decompress(chunk)
          super(chunk)
        end

        private

        def decompress(buffer)
          @_inflaters.reverse_each do |inflater|
            buffer = inflater.inflate(buffer)
          end
          buffer
        end
      end

      class Encoder
        attr_reader :content_type

        def initialize(body, deflater)
          @content_type = body.content_type
          @body = body.respond_to?(:read) ? body : StringIO.new(body.to_s)
          @buffer = StringIO.new("".b, File::RDWR)
          @deflater = deflater
        end

        def each(&blk)
          return enum_for(__method__) unless block_given?

          return deflate(&blk) if @buffer.size.zero?

          @buffer.rewind
          @buffer.each(&blk)
        end

        def bytesize
          deflate
          @buffer.size
        end

        private

        def deflate(&blk)
          return unless @buffer.size.zero?

          @body.rewind
          @deflater.deflate(@body, @buffer, chunk_size: 16_384, &blk)
        end
      end
    end
    register_plugin :compression, Compression
  end
end

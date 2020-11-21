# frozen_string_literal: true

module SessionWithPool
  ConnectionPool = Class.new(HTTPX::Pool) do
    attr_reader :connections
    attr_reader :connection_count
    attr_reader :ping_count

    def initialize(*)
      super
      @connection_count = 0
      @ping_count = 0
    end

    def init_connection(connection, *)
      super
      connection.on(:open) { @connection_count += 1 }
      connection.on(:pong) { @ping_count += 1 }
    end
  end

  module InstanceMethods
    def pool
      @pool ||= ConnectionPool.new
    end
  end

  module ConnectionMethods
    def set_parser_callbacks(parser)
      super
      parser.on(:pong) { emit(:pong) }
    end
  end
end

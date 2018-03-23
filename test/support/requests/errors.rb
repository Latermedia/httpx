module Requests
  module Errors

    def test_connection_refused
      unavailable_host = URI(origin('localhost'))
      unavailable_host.port = next_available_port
      response = HTTPX.get(unavailable_host.to_s)
      assert response.is_a?(HTTPX::ErrorResponse), "response should contain errors"
      assert response.status =~ /Connection refused/, "connection should have been refused"
    end

    private

    def next_available_port
      server = TCPServer.new('localhost', 0)
      server.addr[1]
    ensure
      server.close
    end
  end
end
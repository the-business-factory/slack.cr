require "json"
require "uri/json"

module Slack::Models::Apps
  # The `apps.connections.open` result: a Socket Mode WebSocket URL.
  # The URL works for one connection; call the method again to reconnect.
  struct ConnectionsOpen
    include JSON::Serializable
    include Slack::Api::Envelope

    getter url : URI

    def initialize(@url : URI)
    end
  end
end

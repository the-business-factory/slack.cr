require "uri"

module Slack::Api
  # Gets a Socket Mode WebSocket URL. Requires an app-level token (`xapp-`).
  # See https://docs.slack.dev/reference/methods/apps.connections.open.
  #
  # `SocketMode::Client` calls this for each connection.
  struct AppsConnectionsOpen < Request(Models::Apps::ConnectionsOpen)
    include FormBody

    def method_path : String
      "apps.connections.open"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      URI::Params.new
    end
  end
end

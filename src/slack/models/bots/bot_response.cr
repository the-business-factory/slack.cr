require "json"

module Slack::Models::Bots
  # The `bots.info` response.
  struct BotResponse
    include JSON::Serializable

    getter bot : Slack::Models::Bot
  end
end

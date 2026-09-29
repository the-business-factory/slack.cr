require "json"

module Slack::Models::Pins
  # The pinned items of a channel, from `pins.list`.
  struct PinList
    include JSON::Serializable
    include Slack::Api::Envelope

    getter items : Array(PinnedItem)
  end
end

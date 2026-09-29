require "json"

module Slack::Models::Reactions
  # One page of `reactions.list`. `Client#each_page` reads the next cursor.
  struct ItemList
    include JSON::Serializable
    include Slack::Api::Envelope

    getter items : Array(Item)
  end
end

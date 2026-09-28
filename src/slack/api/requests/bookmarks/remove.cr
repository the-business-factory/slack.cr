require "uri"

module Slack::Api
  # Removes a bookmark from a channel.
  # See https://docs.slack.dev/reference/methods/bookmarks.remove.
  struct BookmarksRemove < Request(Models::DefaultResponse)
    include FormBody

    getter channel_id : String
    getter bookmark_id : String

    def initialize(@channel_id : String, @bookmark_id : String)
    end

    def method_path : String
      "bookmarks.remove"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def form : URI::Params
      URI::Params{"channel_id" => @channel_id, "bookmark_id" => @bookmark_id}
    end
  end
end

require "uri"

module Slack::Api
  # Reads the bookmarks of a channel. See https://docs.slack.dev/reference/methods/bookmarks.list.
  struct BookmarksList < Request(Models::Bookmarks::BookmarkList)
    include FormBody

    getter channel_id : String

    def initialize(@channel_id : String)
    end

    def method_path : String
      "bookmarks.list"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      URI::Params{"channel_id" => @channel_id}
    end
  end
end

require "json"

module Slack::Models::Bookmarks
  # A response with one `bookmark` object, from `bookmarks.add` and `bookmarks.edit`.
  struct BookmarkResponse
    include JSON::Serializable
    include Slack::Api::Envelope

    getter bookmark : Slack::Models::Bookmark
  end
end

require "json"

module Slack::Models::Bookmarks
  # A response with one `bookmark` object, from `bookmarks.add` and `bookmarks.edit`.
  struct BookmarkResponse
    include JSON::Serializable

    getter bookmark : Slack::Models::Bookmark
  end
end

require "json"

module Slack::Models::Bookmarks
  # The bookmarks of a channel, from `bookmarks.list`.
  struct BookmarkList
    include JSON::Serializable
    include Slack::Api::Envelope

    getter bookmarks : Array(Slack::Models::Bookmark)
  end
end

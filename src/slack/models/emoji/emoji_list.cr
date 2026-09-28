require "json"

module Slack::Models::Emoji
  # The `emoji.list` result.
  struct EmojiList
    ALIAS_PREFIX = "alias:"

    include JSON::Serializable

    # Custom emoji names mapped to an image URL, or to `alias:<name>` for an alias.
    getter emoji : Hash(String, String)

    # Unicode emoji categories, present when the request sets `include_categories`.
    # Slack does not document their shape, so they stay raw JSON.
    getter categories : JSON::Any?

    # The emoji that *name* is an alias of, or nil when *name* is not an alias.
    def alias_target(name : String) : String?
      emoji[name]?.try(&.lchop?(ALIAS_PREFIX))
    end
  end
end

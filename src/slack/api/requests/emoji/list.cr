require "uri"

module Slack::Api
  # Lists the workspace's custom emoji. Requires `emoji:read`.
  # See https://docs.slack.dev/reference/methods/emoji.list.
  struct EmojiList < Request(Models::Emoji::EmojiList)
    include FormBody

    # Also return the Unicode emoji categories and the emoji in each category.
    getter? include_categories : Bool

    def initialize(*, @include_categories : Bool = false)
    end

    def method_path : String
      "emoji.list"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def form : URI::Params
      form = URI::Params.new
      form.add "include_categories", "true" if @include_categories
      form
    end
  end
end

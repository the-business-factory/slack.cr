require "uri"

module Slack::Api
  # Reads one conversation. See https://docs.slack.dev/reference/methods/conversations.info.
  struct ConversationsInfo < Request(Models::Conversation)
    include FormBody

    getter channel : String
    getter? include_locale : Bool
    getter? include_num_members : Bool

    def initialize(@channel : String, *, @include_locale : Bool = false, @include_num_members : Bool = false)
    end

    def method_path : String
      "conversations.info"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      form = URI::Params{"channel" => @channel}
      form.add "include_locale", "true" if @include_locale
      form.add "include_num_members", "true" if @include_num_members
      form
    end
  end
end

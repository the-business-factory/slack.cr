require "uri"

module Slack::Api
  # Reads one page of conversation messages.
  # See https://docs.slack.dev/reference/methods/conversations.history.
  struct ConversationsHistory < Request(Models::ConversationsHistory)
    include FormBody

    getter channel : String
    getter cursor : String?
    getter? include_all_metadata : Bool
    getter? inclusive : Bool
    getter latest : String?
    getter oldest : String?

    def initialize(@channel : String, @cursor : String? = nil, @include_all_metadata : Bool = false,
                   @inclusive : Bool = false, @latest : String? = nil, @oldest : String? = nil)
    end

    def method_path : String
      "conversations.history"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      form = URI::Params{"channel" => @channel}
      @cursor.try { |cursor| form.add "cursor", cursor }
      form.add "include_all_metadata", @include_all_metadata.to_s
      form.add "inclusive", @inclusive.to_s
      @latest.try { |latest| form.add "latest", latest }
      @oldest.try { |oldest| form.add "oldest", oldest }
      form
    end
  end
end

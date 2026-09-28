require "uri"

module Slack::Api
  # Reads one page of a message thread.
  # See https://docs.slack.dev/reference/methods/conversations.replies.
  #
  # Since 2025-05-29, Slack limits this method for new apps distributed outside
  # the Marketplace. The client does not enforce that limit.
  struct ConversationsReplies < Request(Models::ConversationsReplies)
    include FormBody
    include Paginated

    getter channel : String
    getter ts : String
    getter? include_all_metadata : Bool
    getter? inclusive : Bool
    getter latest : String?
    getter oldest : String?
    getter cursor : String?
    getter limit : Int32?

    def initialize(@channel : String, @ts : String, *, @include_all_metadata : Bool = false,
                   @inclusive : Bool = false, @latest : String? = nil, @oldest : String? = nil,
                   @cursor : String? = nil, @limit : Int32? = nil)
    end

    def method_path : String
      "conversations.replies"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def validate : Array(UI::ValidationIssue)
      page_issues
    end

    def form : URI::Params
      form = URI::Params{"channel" => @channel, "ts" => @ts}
      form.add "include_all_metadata", "true" if @include_all_metadata
      form.add "inclusive", "true" if @inclusive
      @latest.try { |latest| form.add "latest", latest }
      @oldest.try { |oldest| form.add "oldest", oldest }
      page_fields(form)
      form
    end
  end
end

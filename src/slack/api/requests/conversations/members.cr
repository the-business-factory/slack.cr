require "uri"

module Slack::Api
  # Reads one page of the member IDs of a conversation.
  # See https://docs.slack.dev/reference/methods/conversations.members.
  struct ConversationsMembers < Request(Models::ConversationsMembers)
    include FormBody
    include Paginated

    getter channel : String
    getter cursor : String?
    getter limit : Int32?

    def initialize(@channel : String, *, @cursor : String? = nil, @limit : Int32? = nil)
    end

    def method_path : String
      "conversations.members"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier4
    end

    def validate : Array(UI::ValidationIssue)
      page_issues
    end

    def form : URI::Params
      form = URI::Params{"channel" => @channel}
      page_fields(form)
      form
    end
  end
end

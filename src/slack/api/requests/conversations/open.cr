require "json"

module Slack::Api
  # Opens or resumes a direct message or a group direct message.
  # See https://docs.slack.dev/reference/methods/conversations.open.
  #
  # Open a conversation with *users*, or resume one with its *channel* ID.
  # Slack accepts one form or the other, so each has its own constructor.
  # One user opens a direct message; two to eight open a group direct message.
  #
  # ```
  # dm = client.call(Slack::Api::ConversationsOpen.new(users: ["U123"]))
  # client.call(Slack::Api::ChatPostMessage.new(channel: dm.channel_id, text: "Hello"))
  # ```
  struct ConversationsOpen < Request(Models::Conversations::OpenResponse)
    include JsonBody

    # The documented maximum number of *users*.
    MAX_USERS = 8

    @users : Array(String)?

    getter channel : String?
    getter? return_im : Bool
    getter? prevent_creation : Bool

    # Set *prevent_creation* to resume only an existing conversation. Set
    # *return_im* to read the full conversation object.
    def initialize(*, users : Enumerable(String), @prevent_creation : Bool = false, @return_im : Bool = false)
      # Copy once: Array#to_a returns the caller's array itself.
      @users = users.map(&.itself)
    end

    def initialize(*, channel : String, @return_im : Bool = false)
      @channel = channel
      @prevent_creation = false
    end

    # A copy of the user IDs, or nil for a *channel* request.
    def users : Array(String)?
      @users.dup
    end

    def method_path : String
      "conversations.open"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      @users.try { |users| ConversationChecks.users_issues(issues, "conversations_open", users, MAX_USERS) }
      issues
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        @users.try { |users| json.field "users", users.join(',') }
        @channel.try { |channel| json.field "channel", channel }
        json.field "prevent_creation", true if @prevent_creation
        json.field "return_im", true if @return_im
      end
    end
  end
end

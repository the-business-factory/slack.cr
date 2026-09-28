require "uri"

module Slack::Api
  # Reads one page of the conversations that a user is a member of.
  # See https://docs.slack.dev/reference/methods/users.conversations.
  #
  # Without *user*, Slack reads the conversations of the token's user. Without
  # *types*, Slack returns public channels only.
  struct UsersConversations < Request(Models::ConversationsList)
    include FormBody
    include Paginated

    @types : Array(ConversationType)?

    getter user : String?
    getter? exclude_archived : Bool
    getter? exclude_muted : Bool
    getter team_id : String?
    getter cursor : String?
    getter limit : Int32?

    def initialize(*, @user : String? = nil, types : Enumerable(ConversationType)? = nil,
                   @exclude_archived : Bool = false, @exclude_muted : Bool = false,
                   @team_id : String? = nil, @cursor : String? = nil, @limit : Int32? = nil)
      # Copy once: Array#to_a returns the caller's array itself.
      @types = types.try(&.map(&.itself))
    end

    def types : Array(ConversationType)?
      @types.dup
    end

    def method_path : String
      "users.conversations"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def validate : Array(UI::ValidationIssue)
      issues = page_issues
      if (types = @types) && types.empty?
        issues << UI::ValidationIssue.new(
          "users_conversations.types.empty", "types", "Supply at least one conversation type, or omit types.")
      end
      issues
    end

    def form : URI::Params
      form = URI::Params.new
      @user.try { |user| form.add "user", user }
      @types.try { |types| form.add "types", types.join(',', &.wire_name) }
      form.add "exclude_archived", "true" if @exclude_archived
      form.add "exclude_muted", "true" if @exclude_muted
      @team_id.try { |team_id| form.add "team_id", team_id }
      page_fields(form)
      form
    end
  end
end

require "uri"

module Slack::Api
  # Reads one page of the conversations in a workspace.
  # See https://docs.slack.dev/reference/methods/conversations.list.
  #
  # Without *types*, Slack returns public channels only.
  struct ConversationsList < Request(Models::ConversationsList)
    include FormBody
    include Paginated

    @types : Array(ConversationType)?

    getter? exclude_archived : Bool
    getter team_id : String?
    getter cursor : String?
    getter limit : Int32?

    def initialize(*, types : Enumerable(ConversationType)? = nil, @exclude_archived : Bool = false,
                   @team_id : String? = nil, @cursor : String? = nil, @limit : Int32? = nil)
      # Copy once: Array#to_a returns the caller's array itself.
      @types = types.try(&.map(&.itself))
    end

    def types : Array(ConversationType)?
      @types.dup
    end

    def method_path : String
      "conversations.list"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = page_issues
      if (types = @types) && types.empty?
        issues << UI::ValidationIssue.new(
          "conversations_list.types.empty", "types", "Supply at least one conversation type, or omit types.")
      end
      issues
    end

    def form : URI::Params
      form = URI::Params.new
      form.add "exclude_archived", "true" if @exclude_archived
      @team_id.try { |team_id| form.add "team_id", team_id }
      @types.try { |types| form.add "types", types.join(',', &.wire_name) }
      page_fields(form)
      form
    end
  end
end

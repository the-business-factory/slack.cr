require "uri"

module Slack::Api
  # Reads one page of the items that a user reacted to.
  # See https://docs.slack.dev/reference/methods/reactions.list.
  #
  # Without *user*, Slack reads the token's user. *team_id* is required with an
  # organization token. The legacy `count` and `page` paging is not sent.
  struct ReactionsList < Request(Models::Reactions::ItemList)
    include FormBody
    include Paginated

    getter user : String?
    getter? full : Bool
    getter team_id : String?
    getter cursor : String?
    getter limit : Int32?

    def initialize(*, @user : String? = nil, @full : Bool = false, @team_id : String? = nil,
                   @cursor : String? = nil, @limit : Int32? = nil)
    end

    def method_path : String
      "reactions.list"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      page_issues
    end

    def form : URI::Params
      form = URI::Params.new
      @user.try { |user| form.add "user", user }
      form.add "full", "true" if @full
      @team_id.try { |team_id| form.add "team_id", team_id }
      page_fields(form)
      form
    end
  end
end

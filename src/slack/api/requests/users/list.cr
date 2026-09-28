require "uri"

module Slack::Api
  # Reads one page of the users in a workspace.
  # See https://docs.slack.dev/reference/methods/users.list.
  struct UsersList < Request(Models::Users::UserList)
    include FormBody
    include Paginated

    getter? include_locale : Bool
    getter team_id : String?
    getter cursor : String?
    getter limit : Int32?

    def initialize(*, @include_locale : Bool = false, @team_id : String? = nil,
                   @cursor : String? = nil, @limit : Int32? = nil)
    end

    def method_path : String
      "users.list"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      page_issues
    end

    def form : URI::Params
      form = URI::Params.new
      form.add "include_locale", "true" if @include_locale
      @team_id.try { |team_id| form.add "team_id", team_id }
      page_fields(form)
      form
    end
  end
end

require "uri"

module Slack::Api
  # Reads one page of the workspaces that an org-wide app is approved for.
  # See https://docs.slack.dev/reference/methods/auth.teams.list.
  struct AuthTeamsList < Request(Models::Auth::TeamsList)
    include FormBody
    include Paginated

    getter? include_icon : Bool
    getter cursor : String?
    getter limit : Int32?

    def initialize(*, @include_icon : Bool = false, @cursor : String? = nil, @limit : Int32? = nil)
    end

    def method_path : String
      "auth.teams.list"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      page_issues
    end

    def form : URI::Params
      form = URI::Params.new
      form.add "include_icon", "true" if @include_icon
      page_fields(form)
      form
    end
  end
end

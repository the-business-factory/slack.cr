require "uri"

module Slack::Api
  # Reads a workspace. See https://docs.slack.dev/reference/methods/team.info.
  #
  # Without arguments, Slack reads the token's workspace. Slack accepts
  # *team* or *domain*, not both, so each has its own constructor.
  #
  # ```
  # Slack::Api::TeamInfo.new
  # Slack::Api::TeamInfo.new(team: "T12345")
  # Slack::Api::TeamInfo.new(domain: "example")
  # ```
  struct TeamInfo < Request(Models::Team)
    include FormBody

    getter team : String?
    getter domain : String?

    def initialize
    end

    def initialize(*, team : String)
      @team = team
    end

    # *domain* is the workspace domain from the "Joining This Workspace" setting.
    def initialize(*, domain : String)
      @domain = domain
    end

    def method_path : String
      "team.info"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      form = URI::Params.new
      @team.try { |team| form.add "team", team }
      @domain.try { |domain| form.add "domain", domain }
      form
    end
  end
end

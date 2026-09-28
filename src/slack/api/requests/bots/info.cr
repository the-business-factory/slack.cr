require "uri"

module Slack::Api
  # Reads one bot user. See https://docs.slack.dev/reference/methods/bots.info.
  #
  # *bot* is a bot ID such as `B123456`, for example a message's `bot_id`.
  # *team_id* selects the workspace or organization of the bot.
  struct BotsInfo < Request(Models::Bots::BotResponse)
    include FormBody

    getter bot : String
    getter team_id : String?

    def initialize(*, @bot : String, @team_id : String? = nil)
    end

    def method_path : String
      "bots.info"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      form = URI::Params{"bot" => @bot}
      @team_id.try { |team_id| form.add "team_id", team_id }
      form
    end
  end
end

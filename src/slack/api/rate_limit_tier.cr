module Slack::Api
  # Slack Web API rate limit tiers. See https://docs.slack.dev/apis/web-api/rate-limits.
  #
  # `per_minute` is the documented minimum rate of each numbered tier. Special
  # methods have their own limits; the client paces them at one call per second.
  # The burst sizes are library policy.
  enum RateLimitTier
    Tier1
    Tier2
    Tier3
    Tier4
    Special

    def per_minute : Int32
      case self
      in .tier1?   then 1
      in .tier2?   then 20
      in .tier3?   then 50
      in .tier4?   then 100
      in .special? then 60
      end
    end

    def burst : Int32
      case self
      in .tier1?            then 1
      in .tier2?            then 5
      in .tier3?, .special? then 20
      in .tier4?            then 40
      end
    end

    # Time between calls after the burst is used.
    def interval : Time::Span
      1.minute / per_minute
    end
  end
end

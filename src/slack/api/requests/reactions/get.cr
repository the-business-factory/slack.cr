require "uri"

module Slack::Api
  # Reads the reactions of a message or a file.
  # See https://docs.slack.dev/reference/methods/reactions.get.
  #
  # Slack accepts a message (*channel* and *timestamp*) or a *file*, so each
  # has its own constructor. With *full*, Slack returns every reacting user.
  #
  # ```
  # Slack::Api::ReactionsGet.new(channel: "C123", timestamp: "1710000000.000100")
  # Slack::Api::ReactionsGet.new(file: "F123", full: true)
  # ```
  struct ReactionsGet < Request(Models::Reactions::Item)
    include FormBody

    getter channel : String?
    getter timestamp : String?
    getter file : String?
    getter? full : Bool

    def initialize(*, channel : String, timestamp : String, @full : Bool = false)
      @channel = channel
      @timestamp = timestamp
    end

    def initialize(*, file : String, @full : Bool = false)
      @file = file
    end

    def method_path : String
      "reactions.get"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      form = URI::Params.new
      @channel.try { |channel| form.add "channel", channel }
      @timestamp.try { |timestamp| form.add "timestamp", timestamp }
      @file.try { |file| form.add "file", file }
      form.add "full", "true" if @full
      form
    end
  end
end

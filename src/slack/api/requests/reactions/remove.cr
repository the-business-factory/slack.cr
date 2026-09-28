require "uri"

module Slack::Api
  # Removes an emoji reaction from a message or a file.
  # See https://docs.slack.dev/reference/methods/reactions.remove.
  #
  # Slack accepts a message (*channel* and *timestamp*) or a *file*, so each
  # has its own constructor. Slack answers `no_reaction` when the reaction is
  # not on the item.
  #
  # ```
  # Slack::Api::ReactionsRemove.new("eyes", channel: "C123", timestamp: "1710000000.000100")
  # Slack::Api::ReactionsRemove.new("eyes", file: "F123")
  # ```
  struct ReactionsRemove < Request(Models::DefaultResponse)
    include FormBody

    getter name : String
    getter channel : String?
    getter timestamp : String?
    getter file : String?

    def initialize(@name : String, *, channel : String, timestamp : String)
      @channel = channel
      @timestamp = timestamp
    end

    def initialize(@name : String, *, file : String)
      @file = file
    end

    def method_path : String
      "reactions.remove"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @name.empty?
        issues << UI::ValidationIssue.new("reactions.name.empty", "name", "Reaction name must not be empty.")
      end
      issues
    end

    def form : URI::Params
      form = URI::Params{"name" => @name}
      @channel.try { |channel| form.add "channel", channel }
      @timestamp.try { |timestamp| form.add "timestamp", timestamp }
      @file.try { |file| form.add "file", file }
      form
    end
  end
end

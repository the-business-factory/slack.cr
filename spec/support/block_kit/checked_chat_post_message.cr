require "../../../src/slack"
require "./ui_only"

module Slack::UI::Checked::Proof
  # This Phase 0 adapter uses composition because Api::Base adds setters and a
  # JSON deserializer. The production endpoint remains unchanged.
  class CheckedChatPostMessage
    @snapshot : Message
    @result : HTTP::Client::Response?

    getter channel : String

    def initialize(
      @token : String,
      @channel : String,
      message : Message,
      *,
      @transport : Slack::Auth::Transport? = nil,
    )
      @snapshot = message.snapshot
      @result = nil
    end

    def self.from_json(source : String | IO) : NoReturn
      {% raise "checked request deserialization is unsupported" %}
    end

    def validate : Array(Slack::UI::Checked::ValidationIssue)
      issues = @snapshot.validate
      if @channel.empty?
        issues << Slack::UI::Checked::ValidationIssue.new(
          code: "chat_post_message.channel.empty",
          path: "channel",
          message: "Channel must not be empty."
        )
      end
      issues
    end

    def validate! : Nil
      issues = validate
      raise Slack::UI::Checked::ValidationError.new(issues) unless issues.empty?
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "channel", @channel
        json.field "text", @snapshot.fallback_text
        json.field "blocks" do
          @snapshot.blocks_to_json(json)
        end
      end
    end

    def result : HTTP::Client::Response
      validate!
      @result ||= begin
        descriptor = Slack::Api::ChatPostMessage.new(
          token: @token,
          channel: @channel,
          text: @snapshot.fallback_text
        )
        Slack::ApiClient.new(api: descriptor, transport: @transport).post(body: to_json)
      end
    end

    def call : Slack::Models::Chat::PostMessage
      validate!
      Slack::Api::ResponseHandler(Slack::Models::Chat::PostMessage).from_json(result.body)
    end
  end
end

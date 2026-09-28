# Adds `markdown_text` or `chunks` to a streamed message.
# See https://docs.slack.dev/reference/methods/chat.appendStream.
struct Slack::Api::ChatAppendStream < Slack::Api::Request(Slack::Models::Chat::StreamMessage)
  include Slack::Api::JsonBody

  @content : Streaming::Content

  getter channel : String
  getter ts : String

  def initialize(*, @channel : String, @ts : String, markdown_text : String)
    @content = Streaming::Content.new(markdown_text)
  end

  def initialize(*, @channel : String, @ts : String, chunks : Enumerable(T)) forall T
    @content = Streaming::Content.new(chunks)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = Streaming.stream_issues("chat_append_stream", @channel, @ts)
    issues.concat(@content.validate("chat_append_stream"))
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "ts", @ts
      @content.fields(json)
    end
  end

  def method_path : String
    "chat.appendStream"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier4
  end
end

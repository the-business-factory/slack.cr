# Finishes a streamed message. See https://docs.slack.dev/reference/methods/chat.stopStream.
#
# Give `markdown_text` or `chunks`, or no content. Slack shows *blocks* (up to 50,
# separate from blocks in chunks) after the final message. *metadata* travels with
# the finished message.
struct Slack::Api::ChatStopStream < Slack::Api::Request(Slack::Models::Chat::StreamMessage)
  include Slack::Api::JsonBody

  @content : Streaming::Content
  @blocks : Slack::UI::Message?

  getter channel : String
  getter ts : String
  getter session_status : Streaming::SessionStatus?
  getter metadata : Slack::UI::MessageMetadata?

  def initialize(*, @channel : String, @ts : String, markdown_text : String? = nil,
                 blocks : Enumerable? = nil, @session_status : Streaming::SessionStatus? = nil,
                 @metadata : Slack::UI::MessageMetadata? = nil)
    @content = markdown_text ? Streaming::Content.new(markdown_text) : Streaming::Content.new
    @blocks = final_blocks(blocks)
  end

  def initialize(*, @channel : String, @ts : String, chunks : Enumerable(T),
                 blocks : Enumerable? = nil, @session_status : Streaming::SessionStatus? = nil,
                 @metadata : Slack::UI::MessageMetadata? = nil) forall T
    @content = Streaming::Content.new(chunks)
    @blocks = final_blocks(blocks)
  end

  def blocks : Array(Slack::UI::MessageBlock)?
    @blocks.try(&.blocks)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = Streaming.stream_issues("chat_stop_stream", @channel, @ts)
    issues.concat(@content.validate("chat_stop_stream"))
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "ts", @ts
      @content.fields(json)
      if blocks = @blocks
        json.field "blocks" do
          blocks.blocks_to_json(json)
        end
      end
      if status = @session_status
        json.field "session_status", status.wire_value
      end
      json.field "metadata", @metadata if @metadata
    end
  end

  def method_path : String
    "chat.stopStream"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier2
  end

  # Copies and validates the blocks with the message rules, including the 50-block limit.
  private def final_blocks(blocks : Enumerable?) : Slack::UI::Message?
    blocks.try { |values| Slack::UI::Message.with_slack_generated_fallback(values) }
  end
end

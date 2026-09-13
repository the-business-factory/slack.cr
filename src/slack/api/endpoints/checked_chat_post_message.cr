class Slack::Api::CheckedChatPostMessage
  @snapshot : Slack::UI::Checked::Message
  @result : HTTP::Client::Response?

  getter channel : String
  getter thread_ts : String?
  getter reply_broadcast : Bool?
  getter unfurl_links : Bool?
  getter unfurl_media : Bool?

  def initialize(
    @token : String,
    @channel : String,
    message : Slack::UI::Checked::Message,
    @thread_ts : String? = nil,
    @reply_broadcast : Bool? = nil,
    @unfurl_links : Bool? = nil,
    @unfurl_media : Bool? = nil,
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
    if @reply_broadcast && @thread_ts.nil?
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "chat_post_message.reply_broadcast.thread_required",
        path: "reply_broadcast",
        message: "Reply broadcast requires a thread timestamp."
      )
    end
    issues
  end

  def validate! : Nil
    issues = validate
    raise Slack::UI::Checked::ValidationError.new(issues) unless issues.empty?
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "text", @snapshot.fallback_text if @snapshot.fallback_text
      json.field "blocks" do
        @snapshot.blocks_to_json(json)
      end
      json.field "thread_ts", @thread_ts if @thread_ts
      json.field "reply_broadcast", @reply_broadcast unless @reply_broadcast.nil?
      json.field "unfurl_links", @unfurl_links unless @unfurl_links.nil?
      json.field "unfurl_media", @unfurl_media unless @unfurl_media.nil?
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
      Slack::ApiClient.new(api: descriptor).post(body: to_json)
    end
  end

  def call : Slack::Models::Chat::PostMessage
    validate!
    Slack::Api::ResponseHandler(Slack::Models::Chat::PostMessage).from_json(result.body)
  end
end

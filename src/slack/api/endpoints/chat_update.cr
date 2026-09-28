# Replaces message blocks and explicit fallback text through chat.update.
class Slack::Api::ChatUpdate
  @snapshot : Slack::UI::Message
  @result : HTTP::Client::Response?

  getter channel : String
  getter ts : String
  getter as_user : Bool?

  def initialize(
    @token : String,
    @channel : String,
    @ts : String,
    message : Slack::UI::Message,
    @as_user : Bool? = nil,
    *,
    @configuration : Slack::Auth::APIConfiguration = Slack.settings.api_configuration,
    @transport : Slack::Auth::Transport? = nil,
    @limiter : RateLimiter::LimiterLike? = nil,
  )
    @snapshot = message.snapshot
    @result = nil
  end

  def self.from_json(source : String | IO) : NoReturn
    {% raise "request deserialization is unsupported" %}
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = @snapshot.validate
    if @channel.blank?
      issues << Slack::UI::ValidationIssue.new(
        "chat_update.channel.blank", "channel", "Channel must not be blank.")
    end
    # Keep the timestamp as a string: Slack does not promise fixed digit counts.
    unless /\A[0-9]+\.[0-9]+\z/.matches?(@ts)
      issues << Slack::UI::ValidationIssue.new(
        "chat_update.ts.invalid", "ts", "Message timestamp must contain digits, a decimal point, and fractional digits.")
    end
    if text = @snapshot.fallback_text
      if text.size > 4000
        issues << Slack::UI::ValidationIssue.new(
          "chat_update.text.too_long", "text", "Update fallback text cannot exceed 4000 characters.")
      end
    else
      # Unlike posting, omitting text on update does not promise a new fallback.
      issues << Slack::UI::ValidationIssue.new(
        "chat_update.text.required", "text", "Message updates require explicit fallback text.")
    end
    issues
  end

  def validate! : Nil
    issues = validate
    raise Slack::UI::ValidationError.new(issues) unless issues.empty?
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "ts", @ts
      json.field "text", @snapshot.fallback_text
      json.field "blocks" do
        @snapshot.blocks_to_json(json)
      end
      json.field "as_user", @as_user unless @as_user.nil?
    end
  end

  def result : HTTP::Client::Response
    validate!
    @result ||= begin
      descriptor = JsonBodyRequest(Slack::Models::Chat::UpdateMessage).new(
        token: @token, method_path: "chat.update", body: to_json,
        configuration: @configuration, transport: @transport, limiter: @limiter
      )
      descriptor.result
    end
  end

  def call : Slack::Models::Chat::UpdateMessage
    validate!
    Slack::Api::ResponseHandler(Slack::Models::Chat::UpdateMessage).from_json(result.body)
  end
end

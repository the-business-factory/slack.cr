# Publishes an immutable Home snapshot through the existing API transport.
class Slack::Api::CheckedViewsPublish
  @snapshot : Slack::UI::Checked::Home
  @result : HTTP::Client::Response?

  getter user_id : String
  getter hash : String?
  getter interactivity_pointer : String?

  def initialize(
    @token : String,
    @user_id : String,
    view : Slack::UI::Checked::Home,
    @hash : String? = nil,
    @interactivity_pointer : String? = nil,
    *,
    @configuration : Slack::Auth::APIConfiguration = Slack.settings.api_configuration,
    @transport : Slack::Auth::Transport? = nil,
    @limiter : RateLimiter::LimiterLike? = nil,
  )
    @snapshot = view.snapshot
    @result = nil
  end

  def self.from_json(source : String | IO) : NoReturn
    {% raise "checked request deserialization is unsupported" %}
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = @snapshot.validate.map(&.at("view"))
    if @user_id.empty?
      issues << Slack::UI::Checked::ValidationIssue.new("views_publish.user_id.empty", "user_id", "User ID must not be empty.")
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
      json.field "user_id", @user_id
      json.field "view", @snapshot
      json.field "hash", @hash if @hash
      json.field "interactivity_pointer", @interactivity_pointer if @interactivity_pointer
    end
  end

  def result : HTTP::Client::Response
    validate!
    @result ||= begin
      descriptor = ViewsPublishDescriptor.new(
        token: @token, body: to_json,
        configuration: @configuration, transport: @transport, limiter: @limiter
      )
      descriptor.result
    end
  end

  def call : Slack::Models::ViewsPublish
    validate!
    Slack::Api::ResponseHandler(Slack::Models::ViewsPublish).from_json(result.body)
  end
end

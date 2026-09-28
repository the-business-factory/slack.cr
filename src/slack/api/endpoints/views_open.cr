# Trigger-based views.open adapter. The view snapshot has no Api::Base setters.
class Slack::Api::ViewsOpen
  @snapshot : Slack::UI::Modal
  @result : HTTP::Client::Response?

  getter trigger_id : String

  def initialize(
    @token : String,
    @trigger_id : String,
    view : Slack::UI::Modal,
    *,
    @configuration : Slack::Auth::APIConfiguration = Slack.settings.api_configuration,
    @transport : Slack::Auth::Transport? = nil,
    @limiter : RateLimiter::LimiterLike? = nil,
  )
    @snapshot = view.snapshot
    @result = nil
  end

  def self.from_json(source : String | IO) : NoReturn
    {% raise "request deserialization is unsupported" %}
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = @snapshot.validate.map(&.at("view"))
    if @trigger_id.empty?
      issues << Slack::UI::ValidationIssue.new(
        "views_open.trigger_id.empty", "trigger_id", "Trigger ID must not be empty."
      )
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
      json.field "trigger_id", @trigger_id
      json.field "view", @snapshot
    end
  end

  def result : HTTP::Client::Response
    validate!
    @result ||= begin
      descriptor = JsonBodyRequest(Slack::Models::ViewsOpen).new(
        token: @token, method_path: "views.open", body: to_json,
        configuration: @configuration, transport: @transport, limiter: @limiter
      )
      descriptor.result
    end
  end

  def call : Slack::Models::ViewsOpen
    validate!
    Slack::Api::ResponseHandler(Slack::Models::ViewsOpen).from_json(result.body)
  end
end

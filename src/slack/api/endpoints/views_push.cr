# Trigger-based views.push adapter. The view snapshot has no Api::Base setters.
class Slack::Api::CheckedViewsPush
  @snapshot : Slack::UI::Checked::Modal
  @result : HTTP::Client::Response?

  getter trigger_id : String

  def initialize(
    @token : String,
    @trigger_id : String,
    view : Slack::UI::Checked::Modal,
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
    if @trigger_id.blank?
      issues << Slack::UI::Checked::ValidationIssue.new(
        "views_push.trigger_id.blank", "trigger_id", "Trigger ID must not be blank."
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
      json.field "trigger_id", @trigger_id
      json.field "view", @snapshot
    end
  end

  def result : HTTP::Client::Response
    validate!
    @result ||= begin
      descriptor = JsonBodyRequest(Slack::Models::ViewsPush).new(
        token: @token, method_path: "views.push", body: to_json,
        configuration: @configuration, transport: @transport, limiter: @limiter
      )
      descriptor.result
    end
  end

  def call : Slack::Models::ViewsPush
    validate!
    Slack::Api::ResponseHandler(Slack::Models::ViewsPush).from_json(result.body)
  end
end

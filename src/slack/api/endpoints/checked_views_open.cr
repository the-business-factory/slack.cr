# Trigger-based views.open adapter. The view snapshot has no Api::Base setters.
class Slack::Api::CheckedViewsOpen
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
    if @trigger_id.empty?
      issues << Slack::UI::Checked::ValidationIssue.new(
        "views_open.trigger_id.empty", "trigger_id", "Trigger ID must not be empty."
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
      # Only the legacy descriptor's transport settings are used. Its view is
      # never serialized; the checked envelope is the sole request body.
      descriptor = Slack::Api::ViewsOpen.new(
        token: @token,
        trigger_id: @trigger_id,
        view: Slack::UI::Modal.new(
          title: Slack::UI::Modal::Title.new(@snapshot.title.text),
          blocks: [] of Slack::TypeAliases::ModalBlock
        ),
        configuration: @configuration,
        transport: @transport,
        limiter: @limiter
      )
      descriptor.api_client.post(body: to_json)
    end
  end

  def call : Slack::Models::ViewsOpen
    validate!
    Slack::Api::ResponseHandler(Slack::Models::ViewsOpen).from_json(result.body)
  end
end

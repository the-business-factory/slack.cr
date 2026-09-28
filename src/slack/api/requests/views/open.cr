# Opens a copied modal with a trigger. See https://docs.slack.dev/reference/methods/views.open.
struct Slack::Api::ViewsOpen < Slack::Api::Request(Slack::Models::ViewsOpen)
  include Slack::Api::JsonBody

  @snapshot : Slack::UI::Modal

  getter trigger_id : String

  def initialize(
    @trigger_id : String,
    view : Slack::UI::Modal,
  )
    @snapshot = view.snapshot
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

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "trigger_id", @trigger_id
      json.field "view", @snapshot
    end
  end

  def method_path : String
    "views.open"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier4
  end
end

# Pushes a copied modal with a trigger. See https://docs.slack.dev/reference/methods/views.push.
struct Slack::Api::ViewsPush < Slack::Api::Request(Slack::Models::ViewsPush)
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
    if @trigger_id.blank?
      issues << Slack::UI::ValidationIssue.new(
        "views_push.trigger_id.blank", "trigger_id", "Trigger ID must not be blank."
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
    "views.push"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier4
  end
end

# Outbound JSON acknowledgment that updates the submitted modal view.
# The application must return this JSON in its HTTP 200 response to a
# view_submission within three seconds. This value makes no Web API request.
struct Slack::Interactions::ModalUpdate
  include Slack::UI::Checked::ValueValidation

  @snapshot : Slack::UI::Checked::Modal

  def initialize(view : Slack::UI::Checked::Modal)
    @snapshot = view.snapshot
  end

  # Returns a snapshot; changes do not affect the acknowledgment payload.
  def view : Slack::UI::Checked::Modal
    @snapshot.snapshot
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    @snapshot.validate.map(&.at("view"))
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "response_action", "update"
      json.field "view", @snapshot
    end
  end
end

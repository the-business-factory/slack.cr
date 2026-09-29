require "../socket_mode/response_payload"

# Outbound JSON acknowledgment that pushes a new view after view_submission.
# The application returns this JSON in its HTTP 200 response within three
# seconds. Slack owns the view stack and enforces its three-view limit.
struct Slack::Interactions::ModalPush
  include Slack::SocketMode::ResponsePayload
  include Slack::UI::ValueValidation

  @view : Slack::UI::Modal

  def initialize(view : Slack::UI::Modal)
    @view = view.snapshot
    validate!
  end

  # Returns a snapshot; changes do not affect the acknowledgment payload.
  def view : Slack::UI::Modal
    @view.snapshot
  end

  def validate : Array(Slack::UI::ValidationIssue)
    @view.validate.map(&.at("view"))
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "response_action", "push"
      json.field "view", @view
    end
  end
end

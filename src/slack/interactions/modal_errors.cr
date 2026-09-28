# Outbound JSON acknowledgment for a view_submission with invalid input.
# Keys are Input block IDs; values are plain-text messages, not text objects.
# The application must return this JSON in its HTTP 200 response within three
# seconds and ensure the IDs belong to the submitted view's Input blocks.
struct Slack::Interactions::ModalErrors
  include Slack::UI::Checked::ValueValidation

  @errors : Hash(String, String)

  def initialize(errors : Hash(String, String))
    @errors = errors.dup
    validate!
  end

  # Returns a snapshot; changes do not affect the acknowledgment payload.
  def errors : Hash(String, String)
    @errors.dup
  end

  # A nonempty map and nonblank messages are library policies. No original
  # modal is required, so this cannot check Input block membership.
  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if @errors.empty?
      issues << Slack::UI::Checked::ValidationIssue.new("modal_errors.empty", "errors", "Supply at least one input error.")
    end
    @errors.each do |block_id, message|
      if message.blank?
        issues << Slack::UI::Checked::ValidationIssue.new("modal_errors.message.blank", "errors[#{block_id.inspect}]", "Error message must not be blank.")
      end
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "response_action", "errors"
      json.field "errors", @errors
    end
  end
end

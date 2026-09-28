# Application data that travels with a message.
#
# `event_type` names the event, for example `"task_created"`. `event_payload`
# must be a JSON object. The value keeps its own deep copy of the payload.
# Slack checks the size and format remotely (`metadata_too_large`,
# `invalid_metadata_format`). See https://docs.slack.dev/messaging/message-metadata.
struct Slack::UI::MessageMetadata
  include Slack::UI::ValueValidation

  @event_payload : JSON::Any

  getter event_type : String

  def initialize(@event_type : String, event_payload : JSON::Any)
    @event_payload = event_payload.clone
    validate!
  end

  def self.new(event_type : String, event_payload : Hash(String, JSON::Any)) : self
    new(event_type, JSON::Any.new(event_payload))
  end

  def event_payload : JSON::Any
    @event_payload.clone
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    if @event_type.blank?
      issues << ValidationIssue.new("message_metadata.event_type.blank", "event_type", "Event type must not be blank.")
    end
    unless @event_payload.as_h?
      issues << ValidationIssue.new("message_metadata.event_payload.not_object", "event_payload", "Event payload must be a JSON object.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "event_type", @event_type
      json.field "event_payload", @event_payload
    end
  end
end

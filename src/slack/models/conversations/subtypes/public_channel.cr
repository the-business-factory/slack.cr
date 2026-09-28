# A public channel. Private channels read as `PrivateChannel`.
struct Slack::Models::PublicChannel < Slack::Models::Conversation
  property creator : String,
    members : Array(String)?,
    name : String,
    name_normalized : String,
    previous_names : Array(String),
    purpose : JSON::Any,
    topic : JSON::Any,
    unread_count_display : Int16?,
    unread_count : Int16?

  property? is_archived = false,
    is_general = false,
    is_member = false,
    is_org_shared = false,
    is_shared = false

  @[JSON::Field(converter: Slack::DecimalTimeStampConverter)]
  property last_read : Time?
end

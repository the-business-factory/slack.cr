struct Slack::Models::PublicChannel < Slack::Models::Conversation
  property creator : String,
    id : String,
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
    is_mpim = false,
    is_org_shared = false,
    is_private = false,
    is_shared = false

  @[JSON::Field(converter: Slack::DecimalTimeStampConverter)]
  property last_read : Time?

  def self.from_json(json : String | IO)
    keyed_json_object(json, find_key: "channel")
  end
end

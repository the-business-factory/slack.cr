struct Slack::Api::Channel < Slack::Api::BaseModel
  include JSON::Serializable

  property created : Int32,
    creator : String,
    id : String,
    is_archived : Bool,
    is_changed : Bool?,
    is_general : Bool,
    is_member : Bool,
    is_mpim : Bool,
    is_org_shared : Bool,
    is_private : Bool,
    is_shared : Bool,
    latest : JSON::Any?,
    members : Array(String)?,
    name : String,
    name_normalized : String,
    previous_names : Array(String),
    purpose : JSON::Any,
    topic : JSON::Any,
    unread_count_display : Int16?,
    unread_count : Int16?

  @[JSON::Field(converter: Slack::DecimalTimeStampConverter)]
  property last_read : Time?

  def self.from_json(json : String | IO)
    keyed_json_object(json, find_key: "channel")
  end
end

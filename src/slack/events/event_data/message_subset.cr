struct Slack::EventData::MessageSubset
  include JSON::Serializable

  property attachments : Array(Slack::EventData::Attachment)?,
    client_msg_id : String,
    team : String,
    text : String

  @[JSON::Field(converter: Slack::DecimalTimeStampConverter)]
  property ts : Time
end

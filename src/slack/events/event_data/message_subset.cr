struct Slack::EventData::MessageSubset
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer \
    attachments : Array(Slack::EventData::Attachment)? = [] of Slack::EventData::Attachment,
    client_msg_id : String,
    team : String,
    text : String

  @[JSON::Field(converter: Slack::DecimalTimeStampConverter)]
  properties_with_initializer ts : Time
end

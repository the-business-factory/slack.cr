class Slack::Events::Message < Slack::Event
  property attachments : Array(Slack::EventData::Attachment)?,
    blocks : Array(JSON::Any),
    channel : String,
    channel_type : String,
    client_msg_id : String,
    team : String,
    text : String,
    user : String

  @[JSON::Field(converter: Slack::DecimalTimeStampConverter)]
  property ts : Time

  def public_channel?
    channel_type == "channel"
  end

  def im?
    channel_type == "im"
  end

  def private_channel?
    channel_type == "group"
  end
end

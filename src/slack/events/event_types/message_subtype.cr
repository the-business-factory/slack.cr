class Slack::Events::MessageSubtype < Slack::Event
  property channel : String,
    channel_type : String,
    subtype : String

  @[JSON::Field(converter: Slack::DecimalTimeStampConverter)]
  property event_ts : Time

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

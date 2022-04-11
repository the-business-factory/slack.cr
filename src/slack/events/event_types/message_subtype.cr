class Slack::Events::MessageSubtype < Slack::Event
  property channel : String,
    channel_type : String,
    subtype : String,
    event_ts : String,
    ts : String

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

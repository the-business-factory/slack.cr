class Slack::Events::MessageSubtype < Slack::Event
  property channel : String,
    channel_type : String,
    subtype : String,
    event_ts : String,
    thread_ts : String?,
    ts : String

  def thread?
    thread_ts.present?
  end

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

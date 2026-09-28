# Common fields of a typed message subtype. Slack's reference examples for
# several subtypes omit `channel`, `channel_type`, or `event_ts`, so these are
# nil when Slack omits them.
module Slack::Events::MessageSubtype
  property channel : String?,
    channel_type : String?,
    subtype : String,
    event_ts : String?,
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

  def mpim?
    channel_type == "mpim"
  end
end

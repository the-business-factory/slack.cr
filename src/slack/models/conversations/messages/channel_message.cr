struct Slack::Models::ChannelMessage < Slack::Model
  property attachments : Array(Slack::EventData::Attachment),
    blocks : Array(JSON::Any),
    channel : String,
    channel_type : String,
    client_msg_id : String?,
    team : String,
    text : String,
    user : String

  def self.from_json(json : String | IO)
    keyed_json_object(json, find_key: "channel")
  end
end

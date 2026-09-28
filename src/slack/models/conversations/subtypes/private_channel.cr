struct Slack::Models::PrivateChannel < Slack::Models::Conversation
  def self.from_json(json : String | IO)
    keyed_json_object(json, find_key: "channel")
  end
end

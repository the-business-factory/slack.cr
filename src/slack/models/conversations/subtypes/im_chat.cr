struct Slack::Models::IMChat < Slack::Models::Conversation
  property id : String,
    latest : Slack::Models::DirectMessage,
    user : String

  property? is_im = true

  def self.from_json(json : String | IO)
    keyed_json_object(json, find_key: "channel")
  end
end

struct Slack::Models::IMChat < Slack::Models::ConversationType
  property id : String,
    is_im : Bool,
    latest : Slack::Models::DirectMessage,
    user : String

  def self.from_json(json : String | IO)
    keyed_json_object(json, find_key: "channel")
  end
end

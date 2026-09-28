abstract struct Slack::Models::Conversation < Slack::Model
  @[JSON::Field(converter: Time::EpochConverter)]
  property created : Time

  # Reads the `channel` object of a `conversations.info` response as its conversation type.
  def self.from_json(json : String | IO) : Conversation
    ConversationFactory.from_json(json)
  end
end

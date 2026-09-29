# A public channel, private channel, group direct message, or direct message.
#
# `num_members` and `locale` are present only when the request asks for them.
abstract struct Slack::Models::Conversation < Slack::Model
  property id : String
  property num_members : Int32?
  property locale : String?

  @[JSON::Field(converter: Time::EpochConverter)]
  property created : Time

  # :nodoc:
  # Reads the `channel` object of a `conversations.info` response as its
  # conversation type, and the response's envelope fields.
  def self.from_api_response(body : String) : {Conversation, Api::Envelope}
    response = ConversationBody.from_json(body)
    {response.channel, response}
  end

  # Reads one conversation object, such as an item of `conversations.list`, as its type.
  def self.new(pull : JSON::PullParser) : Conversation
    ConversationFactory.read(pull)
  end
end

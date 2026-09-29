# A public channel, private channel, group direct message, or direct message.
#
# `num_members` and `locale` are present only when the request asks for them.
abstract struct Slack::Models::Conversation < Slack::Model
  property id : String
  property num_members : Int32?
  property locale : String?

  @[JSON::Field(converter: Slack::EpochConverter)]
  property created : Time

  # Reads the `channel` object of a `conversations.info` response as its conversation type.
  def self.from_json(json : String | IO) : Conversation
    keyed_json_object(json, "channel") { |pull| ConversationFactory.read(pull) }
  end

  # :nodoc:
  # Parses a response that holds one conversation in `channel` once, with its
  # envelope values.
  def self.from_api_response(body : String) : Api::DecodedResponse(Conversation)
    ConversationBody.from_api_response(body).map(&.channel)
  end

  # Reads one conversation object, such as an item of `conversations.list`, as its type.
  def self.new(pull : JSON::PullParser) : Conversation
    ConversationFactory.read(pull)
  end
end

require "json"

module Slack::Models::Conversations
  # :nodoc:
  # Reads the `channel` of a `conversations.open` response. With `return_im`,
  # Slack sends the full conversation object, which has `created`: an `IMChat`
  # for a direct message or a `PrivateChannel` for a group direct message.
  # Otherwise the object has only `id`.
  module OpenedChannelConverter
    def self.from_json(pull : JSON::PullParser) : Conversation | ConversationRef
      raw = pull.read_raw
      fields = JSON.parse(raw).as_h? || raise JSON::ParseException.new("Channel must be an object", 0, 0)
      object = JSON::PullParser.new(raw)
      fields.has_key?("created") ? ConversationFactory.read(object) : ConversationRef.new(object)
    end
  end
end

# :nodoc:
# Selects the conversation type from the flags of one conversation object.
# See https://docs.slack.dev/reference/methods/conversations.list: private
# channels have `is_private`; group direct messages also have `is_group` and
# `is_mpim`; older private channels have only `is_group`.
module Slack::Models::ConversationFactory
  def self.read(pull : JSON::PullParser) : Conversation
    raw = pull.read_raw
    flags = JSON.parse(raw).as_h? || raise JSON::ParseException.new("Conversation must be an object", 0, 0)
    object = JSON::PullParser.new(raw)
    if flag?(flags, "is_im")
      IMChat.new(object)
    elsif flag?(flags, "is_private") || flag?(flags, "is_group") || flag?(flags, "is_mpim")
      PrivateChannel.new(object)
    elsif flag?(flags, "is_channel")
      PublicChannel.new(object)
    else
      raise JSON::ParseException.new("Unknown conversation type", 0, 0)
    end
  end

  private def self.flag?(flags : Hash(String, JSON::Any), name : String) : Bool
    flags[name]?.try(&.as_bool?) || false
  end
end

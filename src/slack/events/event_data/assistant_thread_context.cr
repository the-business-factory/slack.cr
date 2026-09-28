# The channel that a user views while an assistant thread is open.
#
# Every field is nil when Slack sends an empty context, for example when the
# user does not view a channel. Call `conversations.info` before you use
# `channel_id`, because the app can have no access to that channel.
struct Slack::EventData::AssistantThreadContext
  include JSON::Serializable

  getter channel_id : String?
  getter team_id : String?
  getter enterprise_id : String?
end

# A message or the message composer has a link to a domain that the app
# unfurls. Give `channel`, `message_ts`, and `unfurl_id` with `source` to
# `chat.unfurl`. For a composer link, `channel` and `message_ts` are not a
# real channel and timestamp, but `chat.unfurl` accepts them.
# https://docs.slack.dev/reference/events/link_shared
struct Slack::Events::LinkShared < Slack::Event
  struct Link
    include JSON::Serializable

    getter domain : String
    getter url : String
  end

  getter channel : String
  getter user : String
  getter message_ts : String
  getter links : Array(Link)

  # Slack does not send `thread_ts` outside a thread, and does not send
  # `unfurl_id` or `source` in an Enterprise organization.
  getter thread_ts : String?
  getter unfurl_id : String?

  # `composer` or `conversations_history`.
  getter source : String?

  getter user_locale : String?

  # True when the bot user is a member of the conversation.
  @[JSON::Field(key: "is_bot_user_member")]
  getter? bot_user_member : Bool

  # True when a user asks to refresh a Work Object unfurl.
  @[JSON::Field(key: "is_unfurl_refresh")]
  getter? unfurl_refresh : Bool = false
end

require "json"

module Slack::Models
  # A bot user from `bots.info`. See https://docs.slack.dev/reference/methods/bots.info.
  #
  # `app_id` identifies the app that owns the bot. `icons` maps names such as
  # `image_48` to URLs. Unknown fields are ignored.
  struct Bot
    include JSON::Serializable

    getter id : String
    getter name : String?
    getter? deleted : Bool = false
    # Unix time of the last change.
    getter updated : Int64?
    getter app_id : String?
    getter user_id : String?
    getter icons : Hash(String, String)?
  end
end

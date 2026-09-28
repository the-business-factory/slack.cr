require "json"

module Slack::Models
  # The profile of a Slack user. See https://docs.slack.dev/reference/objects/user-object.
  #
  # Every field is optional: Slack omits fields that are empty, hidden by scope
  # (`email` needs `users:read.email`), or not set. Custom profile fields stay
  # raw JSON in `fields`, keyed by field ID. Unknown fields are ignored.
  struct UserProfile
    include JSON::Serializable

    getter real_name : String?
    getter display_name : String?
    getter first_name : String?
    getter last_name : String?
    getter email : String?
    getter title : String?
    getter phone : String?
    getter status_text : String?
    getter status_emoji : String?
    # Unix time when the status expires; 0 means the status does not expire.
    getter status_expiration : Int64?
    getter image_72 : String?
    getter image_192 : String?
    getter bot_id : String?
    getter fields : JSON::Any?
  end
end

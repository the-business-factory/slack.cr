require "json"

module Slack::Models
  # A channel bookmark. See https://docs.slack.dev/reference/methods/bookmarks.list.
  #
  # Dates are Unix seconds; `date_updated` is 0 until the bookmark changes.
  struct Bookmark
    include JSON::Serializable

    getter id : String
    getter channel_id : String
    getter title : String
    getter type : String
    getter link : String?
    getter emoji : String?
    getter icon_url : String?
    getter entity_id : String?
    getter parent_id : String?
    getter date_created : Int64
    getter date_updated : Int64 = 0_i64
    getter rank : String?
    getter last_updated_by_user_id : String?
    getter last_updated_by_team_id : String?
  end
end

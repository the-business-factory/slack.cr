require "json"

module Slack::Models
  # A Slack file object. See https://docs.slack.dev/reference/objects/file-object.
  #
  # Only `id` is always present: `files.completeUploadExternal` can return only
  # `id` and `title`. `shares` stays raw JSON.
  struct File
    include JSON::Serializable

    getter id : String
    getter name : String?
    getter title : String?
    getter mimetype : String?
    getter filetype : String?
    getter size : Int64?
    getter url_private : String?
    getter permalink : String?
    getter user : String?
    getter created : Int64?
    getter shares : JSON::Any?
    getter reactions : Array(Slack::Models::Reaction)?
  end
end

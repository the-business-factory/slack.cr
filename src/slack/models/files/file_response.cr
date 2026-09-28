require "json"

module Slack::Models::Files
  # A response with one `file` object, from `files.info` and `files.remote.*`.
  struct FileResponse
    include JSON::Serializable

    getter file : Slack::Models::File
  end
end

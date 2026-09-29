require "json"

module Slack::Models::Files
  # The upload destination from `files.getUploadURLExternal`.
  struct UploadURL
    include JSON::Serializable
    include Slack::Api::Envelope

    getter upload_url : String
    getter file_id : String
  end
end

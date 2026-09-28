require "json"

module Slack::Models::Files
  # The files that `files.completeUploadExternal` completed.
  struct CompletedUpload
    include JSON::Serializable

    getter files : Array(Slack::Models::File)
  end
end

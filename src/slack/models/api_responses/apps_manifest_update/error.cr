module Slack::Models::AppsManifestUpdate
  struct Error < Slack::Models::AppsManifestUpdateResponse
    properties_with_initializer \
      error : String,
      errors : JSON::Any?,
      ok : Bool
  end
end

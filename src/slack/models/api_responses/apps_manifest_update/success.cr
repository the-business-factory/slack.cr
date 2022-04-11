module Slack::Models::AppsManifestUpdate
  struct Success < Slack::Models::AppsManifestUpdateResponse
    properties_with_initializer \
      app_id : String,
      ok : Bool,
      permissions_updated : Bool
  end
end

require "json"
require "uri/json"

module Slack::Models::Apps
  # The `apps.manifest.create` result: the new app's ID, its credentials, and
  # the URL that installs it.
  struct ManifestCreate
    include JSON::Serializable
    include Slack::Api::Envelope

    getter app_id : String
    getter credentials : AppCredentials
    getter oauth_authorize_url : URI
  end
end

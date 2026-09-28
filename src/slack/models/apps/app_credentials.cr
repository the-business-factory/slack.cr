require "json"

module Slack::Models::Apps
  # The credentials of an app that `apps.manifest.create` made. The secrets are
  # `Auth::Secret` values, so `inspect` and `to_s` redact them. Store them securely.
  struct AppCredentials
    include JSON::Serializable

    getter client_id : String

    @[JSON::Field(converter: Slack::Interactions::SecretConverter, ignore_serialize: true)]
    getter client_secret : Slack::Auth::Secret

    @[JSON::Field(converter: Slack::Interactions::SecretConverter, ignore_serialize: true)]
    getter verification_token : Slack::Auth::Secret

    @[JSON::Field(converter: Slack::Interactions::SecretConverter, ignore_serialize: true)]
    getter signing_secret : Slack::Auth::Secret
  end
end

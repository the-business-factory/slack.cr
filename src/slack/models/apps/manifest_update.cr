struct Slack::Models::Apps::ManifestUpdate < Slack::Model
  include Slack::Api::Envelope
  properties_with_initializer \
    app_id : String,
    permissions_updated : Bool
end

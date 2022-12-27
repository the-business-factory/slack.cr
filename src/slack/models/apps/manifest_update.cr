struct Slack::Models::Apps::ManifestUpdate < Slack::Model
  properties_with_initializer \
    app_id : String,
    permissions_updated : Bool

  property? ok = true
end

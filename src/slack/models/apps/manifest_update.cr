struct Slack::Models::Apps::ManifestUpdate < Slack::Model
  properties_with_initializer \
    app_id : String,
    ok : Bool,
    permissions_updated : Bool
end

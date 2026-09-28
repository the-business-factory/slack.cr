# What a user views in Slack while the app is visible, from an
# `app_context_changed` event. `entities` is empty when Slack sends an empty
# context.
struct Slack::EventData::AppContext
  include JSON::Serializable

  # Ordered from most to least relevant.
  getter entities : Array(ContextEntity) = [] of ContextEntity
end

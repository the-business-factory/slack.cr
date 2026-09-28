# Inbound view fields remain raw JSON, including Slack's IDs, state, and hash.
struct Slack::Models::ViewsUpdate < Slack::Model
  properties_with_initializer view : JSON::Any

  property? ok = true
end

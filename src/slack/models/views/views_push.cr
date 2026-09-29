# Inbound view fields remain raw JSON, including Slack's IDs, state, and hash.
struct Slack::Models::ViewsPush < Slack::Model
  include Slack::Api::Envelope
  properties_with_initializer view : JSON::Any
end

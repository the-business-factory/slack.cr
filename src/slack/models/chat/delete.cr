struct Slack::Models::Chat::Delete < Slack::Model
  include Slack::Api::Envelope
  properties_with_initializer channel : String, ts : String
end

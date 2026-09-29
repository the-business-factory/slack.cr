# Where Slack placed a `/me` message.
struct Slack::Models::Chat::MeMessage < Slack::Model
  include Slack::Api::Envelope
  getter channel : String
  getter ts : String
end

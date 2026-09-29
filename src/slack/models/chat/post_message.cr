# The posted message and where Slack placed it.
struct Slack::Models::Chat::PostMessage < Slack::Model
  include Slack::Api::Envelope
  properties_with_initializer \
    channel : String? = nil,
    message : Slack::Models::Message,
    ts : String
end

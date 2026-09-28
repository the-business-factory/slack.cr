# The posted message and where Slack placed it.
struct Slack::Models::Chat::PostMessage < Slack::Model
  properties_with_initializer \
    channel : String? = nil,
    message : Slack::Models::Message,
    ts : String

  property? ok = true
end

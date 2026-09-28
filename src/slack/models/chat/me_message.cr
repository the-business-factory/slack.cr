# Where Slack placed a `/me` message.
struct Slack::Models::Chat::MeMessage < Slack::Model
  getter channel : String
  getter ts : String

  property? ok = true
end

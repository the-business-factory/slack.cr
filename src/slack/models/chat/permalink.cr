# The permanent URL of a message.
struct Slack::Models::Chat::Permalink < Slack::Model
  getter channel : String
  getter permalink : String

  property? ok = true
end

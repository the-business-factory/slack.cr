# The permanent URL of a message.
struct Slack::Models::Chat::Permalink < Slack::Model
  include Slack::Api::Envelope
  getter channel : String
  getter permalink : String
end

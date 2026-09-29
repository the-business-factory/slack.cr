struct Slack::Models::ViewsOpen < Slack::Model
  include Slack::Api::Envelope
  properties_with_initializer view : JSON::Any
end

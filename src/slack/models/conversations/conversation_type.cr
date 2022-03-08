abstract struct Slack::Models::ConversationType < Slack::Models::Base
  @[JSON::Field(converter: Time::EpochConverter)]
  property created : Time
end

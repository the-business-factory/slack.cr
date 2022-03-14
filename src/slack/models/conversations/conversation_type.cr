abstract struct Slack::Models::ConversationType < Slack::Model
  @[JSON::Field(converter: Time::EpochConverter)]
  property created : Time
end

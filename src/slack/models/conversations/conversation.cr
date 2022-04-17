abstract struct Slack::Models::Conversation < Slack::Model
  @[JSON::Field(converter: Time::EpochConverter)]
  property created : Time
end

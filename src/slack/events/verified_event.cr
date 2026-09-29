struct Slack::VerifiedEvent
  include JSON::Serializable
  include Slack::InitializerMacros

  Slack::Events::EnvelopeFields.declare(Slack::Event)
end

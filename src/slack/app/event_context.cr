# The context of an `App#event` listener. The app acknowledges the event
# before the listener runs, so the listener has no `ack`.
struct Slack::App::EventContext < Slack::App::Context
  getter envelope : Slack::VerifiedEvent

  def initialize(environment : Environment, @envelope : Slack::VerifiedEvent)
    super(environment)
  end

  def event : Slack::Event
    @envelope.event
  end
end

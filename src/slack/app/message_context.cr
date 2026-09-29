# The context of an `App#message` listener. The app acknowledges the event
# before the listener runs, so the listener has no `ack`.
struct Slack::App::MessageContext < Slack::App::Context
  include Saying

  getter envelope : Slack::VerifiedEvent
  getter message : Slack::Events::Message

  def initialize(environment : Environment, @envelope : Slack::VerifiedEvent, @message : Slack::Events::Message)
    super(environment)
  end

  private def say_channel : String
    @message.channel
  end
end

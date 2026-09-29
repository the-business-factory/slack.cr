# The context of an `App#event`, `App#message`, or generated `App#on_*`
# listener. *T* is the event type that the listener matched, so `#event`
# needs no cast. The app acknowledges the event before the listener runs, so
# the listener has no `ack`.
#
# ```
# app.event(Slack::Events::AppMentioned) do |ctx|
#   ctx.say("You said: #{ctx.event.text}")
# end
# ```
struct Slack::App::EventContext(T) < Slack::App::Context
  include Saying

  getter envelope : Slack::VerifiedEvent
  getter event : T

  def initialize(environment : Environment, @envelope : Slack::VerifiedEvent, @event : T)
    super(environment)
  end

  # The conversation of events that happen in one, as in Bolt: messages,
  # mentions, App Home, membership changes, reactions, pins, and shared links.
  private def say_channel : String?
    case event = @event
    when Slack::Events::AppMentioned, Slack::Events::AppHomeOpened, Slack::Events::MemberJoinedChannel,
         Slack::Events::MemberLeftChannel, Slack::Events::LinkShared, Slack::Events::Message,
         Slack::Events::MessageSubtype
      event.channel
    when Slack::Events::Message::Unmapped then event.raw["channel"]?.try(&.as_s?)
    when Slack::Events::ReactionAdded, Slack::Events::ReactionRemoved
      item = event.item
      item.channel if item.is_a?(Slack::EventData::ReactionItem::Message)
    when Slack::Events::PinAdded, Slack::Events::PinRemoved then event.channel_id
    end
  end
end

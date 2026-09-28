# The context of an `App#event` listener. The app acknowledges the event
# before the listener runs, so the listener has no `ack`.
struct Slack::App::EventContext < Slack::App::Context
  include Saying

  getter envelope : Slack::VerifiedEvent

  def initialize(environment : Environment, @envelope : Slack::VerifiedEvent)
    super(environment)
  end

  def event : Slack::Event
    @envelope.event
  end

  # The conversation of events that happen in one, as in Bolt: messages,
  # mentions, App Home, membership changes, reactions, pins, and shared links.
  private def say_channel : String?
    case event = @envelope.event
    when Slack::Events::AppMentioned, Slack::Events::AppHomeOpened, Slack::Events::MemberJoinedChannel,
         Slack::Events::MemberLeftChannel, Slack::Events::LinkShared, Slack::Events::Message,
         Slack::Events::MessageSubtype
      event.channel
    when Slack::Events::ReactionAdded, Slack::Events::ReactionRemoved
      item = event.item
      item.channel if item.is_a?(Slack::EventData::ReactionItem::Message)
    when Slack::Events::PinAdded, Slack::Events::PinRemoved then event.channel_id
    end
  end
end

# The context of an `App#action` listener for a `block_actions` payload.
# `#action` is the first action in the payload; Slack sends one per click.
struct Slack::App::ActionContext < Slack::App::Context
  include Acknowledging
  include FunctionInteractivity
  include Saying
  include Responding

  getter payload : Slack::Interactions::BlockAction
  getter action : Slack::Interactions::Action

  def initialize(environment : Environment, @payload : Slack::Interactions::BlockAction,
                 @action : Slack::Interactions::Action)
    super(environment)
  end

  # Nil for a click in a modal or in App Home.
  private def say_channel : String?
    @payload.channel.try(&.id)
  end

  # Nil for a click in a modal or in App Home.
  private def response_url : String?
    @payload.response_url
  end
end

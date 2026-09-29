# The context of an `App#action` listener for a `block_actions` payload.
# `#action` is the first action in the payload; Slack sends one per click.
#
# *T* is the action type. A listener registered with an element type, such as
# `App#action(Slack::Interactions::ButtonAction, "deploy.approve")`, gets an
# `ActionContext(Slack::Interactions::ButtonAction)`. A listener registered
# with an action ID only gets `ActionContext(Slack::Interactions::Action)`.
struct Slack::App::ActionContext(T) < Slack::App::Context
  include Acknowledging
  include FunctionInteractivity
  include Saying
  include Responding

  getter payload : Slack::Interactions::BlockAction
  getter action : T

  def initialize(environment : Environment, @payload : Slack::Interactions::BlockAction, @action : T)
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

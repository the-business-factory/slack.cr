# The context of an `App#action` listener for a `block_actions` payload.
# `#action` is the first action in the payload; Slack sends one per click.
struct Slack::App::ActionContext < Slack::App::Context
  include Acknowledging

  getter payload : Slack::Interactions::BlockAction
  getter action : Slack::Interactions::Action

  def initialize(environment : Environment, @payload : Slack::Interactions::BlockAction,
                 @action : Slack::Interactions::Action)
    super(environment)
  end
end

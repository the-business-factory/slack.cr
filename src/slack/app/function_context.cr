# The context of an `App#function` listener for a `function_executed` event.
# The app acknowledges the event before the listener runs.
struct Slack::App::FunctionContext < Slack::App::Context
  getter envelope : Slack::VerifiedEvent
  getter event : Slack::Events::FunctionExecuted

  def initialize(environment : Environment, @envelope : Slack::VerifiedEvent, @event : Slack::Events::FunctionExecuted)
    super(environment)
  end
end

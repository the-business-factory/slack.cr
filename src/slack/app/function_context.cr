# The context of an `App#function` listener for a `function_executed` event.
# The app acknowledges the event before the listener runs.
#
# `#client` has the event's workflow token (`bot_access_token`), not the app
# token. Call `#complete` or `#fail` when the step is done. A step that waits
# for a user can instead finish from the action or view listener of the blocks
# it posted; see `ActionContext#function_execution`.
#
# ```
# app.function("approve_request") do |ctx|
#   ctx.complete({approver: ctx.inputs["requester"].as_s})
# end
# ```
struct Slack::App::FunctionContext < Slack::App::Context
  getter envelope : Slack::VerifiedEvent
  getter event : Slack::Events::FunctionExecuted
  getter execution : FunctionExecution

  def initialize(environment : Environment, @envelope : Slack::VerifiedEvent, @event : Slack::Events::FunctionExecuted)
    super(environment)
    @execution = FunctionExecution.new(event.function_execution_id, event.function.callback_id, event.inputs,
      environment.workflow_client.call(event.bot_access_token))
  end

  # Web API client with the event's workflow token.
  def client : Slack::Api::Client
    @execution.client
  end

  # The step inputs, keyed by input parameter name.
  def inputs : JSON::Any
    @execution.inputs
  end

  # See `FunctionExecution#complete`.
  def complete(outputs : NamedTuple | Hash = NamedTuple.new) : Nil
    @execution.complete(outputs)
  end

  # See `FunctionExecution#fail`.
  def fail(error : String) : Nil
    @execution.fail(error)
  end
end

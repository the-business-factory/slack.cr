# A running custom step (a function execution) that the app completes or fails.
# Its client sends requests with the workflow token (`bot_access_token`) that
# Slack gave for the execution, not with the app token.
#
# A workflow waits until the app calls `#complete` or `#fail` once. Slack
# rejects a second call with `execution_not_in_running_state`.
struct Slack::App::FunctionExecution
  # The `function_execution_id`.
  getter id : String
  getter callback_id : String
  # The step inputs, keyed by input parameter name.
  getter inputs : JSON::Any
  # Web API client with the workflow token.
  getter client : Slack::Api::Client

  def initialize(@id : String, @callback_id : String, @inputs : JSON::Any, @client : Slack::Api::Client)
  end

  # Completes the step with *outputs*, keyed by output parameter name, through
  # `functions.completeSuccess`. Raises `Api::Error` when Slack rejects it.
  def complete(outputs : NamedTuple | Hash = NamedTuple.new) : Nil
    @client.call(Slack::Api::FunctionsCompleteSuccess.new(@id, outputs))
    nil
  end

  # Fails the step with *error*, a message for the workflow user, through
  # `functions.completeError`. Raises `Api::Error` when Slack rejects it.
  def fail(error : String) : Nil
    @client.call(Slack::Api::FunctionsCompleteError.new(@id, error))
    nil
  end
end

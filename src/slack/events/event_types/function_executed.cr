# Slack runs a custom function of this app as a workflow step.
#
# Complete the execution with `Api::FunctionsCompleteSuccess` or
# `Api::FunctionsCompleteError`, sent with `bot_access_token` as the client token.
# https://docs.slack.dev/reference/events/function_executed
struct Slack::Events::FunctionExecuted < Slack::Event
  getter function : FunctionDefinition

  # The function inputs, keyed by input parameter name. Values keep their raw JSON types.
  getter inputs : JSON::Any

  getter function_execution_id : String
  getter workflow_execution_id : String
  getter event_ts : String

  # The workflow token for this execution. `inspect` and `to_s` redact it, and
  # `to_json` omits it.
  @[JSON::Field(converter: Slack::Interactions::SecretConverter, ignore_serialize: true)]
  getter bot_access_token : Slack::Auth::Secret
end

# Workflow steps

A custom function is a workflow step that your app runs. Workflow Builder users add the step to a workflow. When the workflow reaches the step, Slack sends the app a `function_executed` event. The app reads the inputs, does the work, and then completes or fails the execution.

Offline specs and examples do not prove that Slack accepts a manifest, runs a workflow, or accepts a completion.

## Define the function in the app manifest

Define each function in the `functions` object of the app manifest. The key is the function `callback_id`. This library does not model the manifest; the snippet below is Slack manifest JSON from the Bolt custom steps guide.

```json
"functions": {
  "custom_step_button": {
    "title": "Custom step with a button",
    "description": "Custom step that waits for a button click",
    "input_parameters": {
      "user_id": {
        "type": "slack#/types/user_id",
        "title": "User",
        "description": "The recipient of a message with a button",
        "is_required": true
      }
    },
    "output_parameters": {
      "user_id": {
        "type": "slack#/types/user_id",
        "title": "User",
        "description": "The user that completed the function",
        "is_required": true
      }
    }
  }
}
```

Subscribe the app to the `function_executed` bot event. The event needs no OAuth scope.

## Read the event

`Slack::Events::FunctionExecuted` has these fields:

| Field | Type | Content |
| --- | --- | --- |
| `function` | `FunctionDefinition` | `id`, `callback_id`, `title`, `description`, `type`, `app_id`, `input_parameters`, `output_parameters`, `date_created`, `date_updated`, and `date_deleted` (nil when the function is not deleted) |
| `inputs` | `JSON::Any` | The input values, keyed by input parameter name |
| `function_execution_id` | `String` | The ID to complete or fail |
| `workflow_execution_id` | `String` | The workflow run |
| `event_ts` | `String` | The event timestamp |
| `bot_access_token` | `Auth::Secret` | The token for this execution |

Each `FunctionParameter` has `type`, `name`, `title`, `description`, and `required?`.

The library does not convert inputs to typed values. Read each value from `inputs` with the JSON type of its Slack type. For example, `slack#/types/user_id` is a string:

```crystal
event = envelope.event
if event.is_a?(Slack::Events::FunctionExecuted) && event.function.callback_id == "custom_step_button"
  user_id = event.inputs["user_id"].as_s
end
```

`inspect`, `to_s`, and `to_json` do not show `bot_access_token`. Do not log `bot_access_token.value`.

## Complete or fail the execution

Send the completion with a client that uses the event's `bot_access_token`. Each execution has its own token. Send `outputs` keyed by output parameter name. Send an empty `outputs` object when the function has no outputs.

```crystal
client = Slack::Api::Client.new(token: event.bot_access_token)

client.call(Slack::Api::FunctionsCompleteSuccess.new(
  function_execution_id: event.function_execution_id,
  outputs: {user_id: user_id}))
```

When the step cannot finish, send a human-readable message that explains why:

```crystal
client.call(Slack::Api::FunctionsCompleteError.new(
  function_execution_id: event.function_execution_id,
  error: "The user was not found."))
```

Both methods are Tier 3. Slack returns these errors, which `Slack::Api::Error#code` gives:

- `execution_not_in_running_state`: the execution already completed or failed.
- `function_execution_not_found`: Slack does not find the execution.
- `parameter_validation_failed` (`functions.completeSuccess` only): the outputs do not match the output parameters.

The library does not check outputs against the manifest.

## Example

`examples/workflow_step.cr` decodes two synthetic `function_executed` events. It completes the first one with outputs and fails the second one, which has no input. It uses a WebMock transport and does not contact Slack.

```sh
crystal run examples/workflow_step.cr
```

# Function execution metadata. Slack sends it only for interactions with blocks
# or views that a custom workflow step created.
# https://docs.slack.dev/reference/interaction-payloads/block_actions-payload/
struct Slack::Interactions::FunctionData
  include JSON::Serializable

  getter execution_id : String
  getter function : FunctionRef
  # The function inputs, keyed by input name. Values keep their raw JSON types.
  getter inputs : JSON::Any

  def initialize(@execution_id : String, @function : FunctionRef, @inputs : JSON::Any)
  end
end

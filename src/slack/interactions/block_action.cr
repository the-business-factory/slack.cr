# https://api.slack.com/reference/interaction-payloads/block-actions
struct Slack::Interactions::BlockAction < Slack::Interaction
  property actions : JSON::Any,
    api_app_id : String,
    channel : JSON::Any,
    container : JSON::Any,
    state : JSON::Any,
    token : String,
    trigger_id : String,
    user : JSON::Any,
    team : JSON::Any
end

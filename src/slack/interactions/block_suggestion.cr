# Options-load request for an external select menu. Slack posts it to the
# app's Options Load URL whenever the menu opens or its typeahead query changes.
# Answer with a BlockSuggestionResponse in an HTTP 200 response.
# https://docs.slack.dev/reference/interaction-payloads/block_suggestion-payload
struct Slack::Interactions::BlockSuggestion < Slack::Interaction
  getter action_id : String
  getter block_id : String
  # The typed query. Slack sends an empty string when the menu first opens.
  getter value : String

  @[JSON::Field(emit_null: false)]
  getter container : JSON::Any?

  @[JSON::Field(emit_null: false)]
  getter channel : JSON::Any?

  # Present when the menu is in a message.
  @[JSON::Field(emit_null: false)]
  getter message : JSON::Any?

  # Present when the menu is in a modal or Home view.
  @[JSON::Field(emit_null: false)]
  getter view : Slack::Interactions::View?

  @[JSON::Field(emit_null: false)]
  getter token : String?
end

# The `action_id` of an interactive element, as one value that the element and
# its listener share.
#
# Every block element that takes `action_id:` accepts an `ActionId` or a
# `String`. `Slack::App#action` and `Slack::App#options` accept an `ActionId`
# also. Use one constant for both, so that the element and its listener cannot
# use different IDs:
#
# ```
# APPROVE = Slack::UI::ActionId.new("deploy.approve")
#
# button = Slack::UI::BlockElements::Button.new(
#   text: Slack::UI.plain("Approve"),
#   action_id: APPROVE,
# )
# app.action(APPROVE) { |ctx| ctx.ack }
# ```
#
# The element validates the ID (for example, its maximum length). This type
# does not.
record Slack::UI::ActionId, value : String do
  # Returns the wire string of *id*.
  def self.value_of(id : String | ActionId) : String
    id.is_a?(ActionId) ? id.value : id
  end

  # Returns nil when an optional `action_id:` argument is not given.
  def self.value_of(id : Nil) : Nil
  end

  # Writes the wire string of this ID.
  def to_s(io : IO) : Nil
    io << value
  end
end

# The icon of a message that an app posts: `Icon::Emoji` or `Icon::Url`.
# Slack uses the emoji when a request sends both, so a message has only one.
module Slack::UI::Icon
  # The request field name: `icon_emoji` or `icon_url`.
  abstract def wire_field : String
  abstract def value : String
end

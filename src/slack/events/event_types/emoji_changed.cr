# A custom emoji was added, removed, or renamed.
#
# `subtype`, when present, is `add` (with `name` and `value`), `remove` (with `names`), or
# `rename` (with `old_name`, `new_name`, and `value`). Without a known
# subtype, reload the emoji list with `emoji.list`.
# https://docs.slack.dev/reference/events/emoji_changed
struct Slack::Events::EmojiChanged < Slack::Event
  getter subtype : String?
  getter name : String?
  getter names : Array(String) = [] of String
  getter old_name : String?
  getter new_name : String?

  # The image URL, or `alias:<name>` for an alias.
  getter value : String?

  getter event_ts : String
end

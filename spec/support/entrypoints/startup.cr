# A consumer program that reaches the library only through `require "slack"` on
# CRYSTAL_PATH: no spec helper, credentials, or global configuration. It is
# type-checked without codegen by spec/entrypoints_spec.cr.
require "slack"

message = Slack::UI.message(fallback_text: "No credentials required") do |builder|
  builder.section(Slack::UI.plain("Ready"))
end
message.to_json

# Test support loads only with `require "slack/testing"`.
{% if Slack.has_constant?("Testing") %}
  {% raise "require \"slack\" loaded Slack::Testing" %}
{% end %}

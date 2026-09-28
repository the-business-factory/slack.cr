require "slack"

# No spec helper, environment variables, credentials, or global configuration at startup.
message = Slack::UI.message(fallback_text: "No credentials required") do |builder|
  builder.section(Slack::UI.plain("Ready"))
end
raise "Incorrect message" unless JSON.parse(message.to_json)["blocks"][0]["text"]["text"] == "Ready"

# Test support loads only with `require "slack/testing"`.
{% if Slack.has_constant?("Testing") %}
  {% raise "require \"slack\" loaded Slack::Testing" %}
{% end %}

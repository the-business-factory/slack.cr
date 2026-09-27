require "slack/ui"

message = Slack::UI::Checked.message(fallback_text: "UI entrypoint") do |builder|
  builder.section(Slack::UI::Checked.plain("No credentials required"))
end

raise "checked UI entrypoint failed" unless JSON.parse(message.to_json)["blocks"].as_a.size == 1

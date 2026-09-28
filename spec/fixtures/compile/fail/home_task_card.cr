require "../../../../src/slack/ui"

alias UI = Slack::UI

UI::Home.new(blocks: [UI::Blocks::TaskCard.new(task_id: "read", title: "Read the report", status: UI::TaskStatus::Complete)])

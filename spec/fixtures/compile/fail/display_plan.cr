require "../../../../src/slack/ui"

alias UI = Slack::UI

task = UI::Blocks::TaskCard.new(task_id: "read", title: "Read the report", status: UI::TaskStatus::Complete)
UI::DisplayModal.new(title: UI.plain("Display"), blocks: [UI::Blocks::Plan.new(title: "Plan", tasks: {task}), UI::Blocks::Divider.new])

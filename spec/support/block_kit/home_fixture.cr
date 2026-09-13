module HomeFixture
  alias UI = Slack::UI::Checked

  def self.builder : UI::HomeBuilder
    builder = UI::HomeBuilder.new(private_metadata: "", callback_id: "dashboard", external_id: "dashboard-U123")
    builder.header(text: UI.plain("Your projects", emoji: false), block_id: "heading", level: 1)
    builder.context(elements: {UI.plain("Updated today"), UI.mrkdwn("*Ready*", verbatim: false), UI::BlockElements::Image.new(slack_file: UI::CompositionObjects::SlackFile.new(id: "F123"), alt_text: "Project thumbnail")}, block_id: "status")
    builder.section(text: UI.mrkdwn("*Project 42*"), accessory: UI::BlockElements::Image.new(image_url: "https://example.test/thumbnail.png", alt_text: "Project 42 thumbnail"), block_id: "summary", expand: false)
    builder.image(slack_file: UI::CompositionObjects::SlackFile.new(url: "https://files.slack.com/files-pri/T123-F123/project.png"), alt_text: "Project 42 diagram", title: UI.plain("Diagram"), block_id: "diagram")
    builder.actions(elements: [UI::BlockElements::Button.new(text: UI.plain("Refresh"), action_id: "refresh", accessibility_label: "Refresh your projects")], block_id: "controls")
    builder.input(label: UI.plain("Project note"), hint: UI.plain("Press Enter to save"), block_id: "note", optional: true, dispatch_action: true,
      element: UI::BlockElements::PlainTextInput.new(action_id: "text", initial_value: "", multiline: false, focus_on_load: true, min_length: 0, max_length: 3000,
        placeholder: UI.plain("Add a note"), dispatch_action_config: UI::CompositionObjects::DispatchActionConfig.new(trigger_actions_on: [UI::CompositionObjects::DispatchTrigger::OnEnterPressed])))
    builder.divider(block_id: "end")
    builder
  end
end

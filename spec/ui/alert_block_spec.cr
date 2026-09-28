require "../../spec_helper"

module AlertBlockSpec
  alias UI = Slack::UI::Checked

  describe UI::Blocks::Alert do
    it "serializes alert levels and text formats in a display modal" do
      modal = UI.display_modal(title: UI.plain("Deploy status")) do |builder|
        builder.alert(UI.mrkdwn("The work is mysterious and important.", verbatim: false), level: UI::Blocks::AlertLevel::Info)
        builder.alert(UI.plain("Deploy 42 failed."), level: UI::Blocks::AlertLevel::Error, block_id: "deploy.failed")
        builder.add(UI::Blocks::Alert.new(UI.plain("No level uses Slack's default.")))
        builder.divider
      end

      JSON.parse(modal.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/alert_display_modal.json"))
    end

    it "sends each documented level, including an explicit default, next to Input in a form modal" do
      label = UI.plain("Reason")
      form = UI.form_modal(title: UI.plain("Request"), submit: UI.plain("Send")) do |builder|
        {UI::Blocks::AlertLevel::Default, UI::Blocks::AlertLevel::Warning, UI::Blocks::AlertLevel::Success}.each do |level|
          builder.alert(UI.plain("Check"), level: level)
        end
        builder.input(label: label, element: UI::BlockElements::PlainTextInput.new(action_id: "reason"))
      end

      JSON.parse(form.to_json)["blocks"].should eq JSON.parse(<<-JSON)
        [{"type":"alert","text":{"type":"plain_text","text":"Check"},"level":"default"},
         {"type":"alert","text":{"type":"plain_text","text":"Check"},"level":"warning"},
         {"type":"alert","text":{"type":"plain_text","text":"Check"},"level":"success"},
         {"type":"input","label":{"type":"plain_text","text":"Reason"},
          "element":{"type":"plain_text_input","action_id":"reason"}}]
        JSON
    end

    it "accepts 200 characters of text and rejects longer text and block IDs" do
      UI::Blocks::Alert.new(UI.mrkdwn("a" * 200)).validate.should be_empty

      error = expect_raises(UI::ValidationError) do
        UI::Blocks::Alert.new(UI.mrkdwn("a" * 201), block_id: "b" * 256)
      end
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"alert.text.too_long", "text.text"},
        {"alert.block_id.too_long", "block_id"},
      ]
    end

    it "reports duplicate alert block IDs within a view" do
      error = expect_raises(UI::ValidationError) do
        UI::DisplayModal.new(title: UI.plain("Status"), blocks: [
          UI::Blocks::Alert.new(UI.plain("One"), block_id: "status"),
          UI::Blocks::Alert.new(UI.plain("Two"), block_id: "status"),
        ])
      end
      error.issues.map(&.code).should eq ["modal.block_id.duplicate"]
    end
  end
end

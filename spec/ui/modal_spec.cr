require "../spec_helper"

describe "Modal surfaces" do
  it "emits all modal fields at their exact wire level" do
    modal = Slack::UI.form_modal(
      title: Slack::UI.plain("Request", emoji: false), submit: Slack::UI.plain("Send"),
      close: Slack::UI.plain("Cancel"), private_metadata: "", callback_id: "request", external_id: "request-42",
      clear_on_close: false, notify_on_close: true, submit_disabled: false
    ) do |builder|
      builder.input(label: Slack::UI.plain("Reason"), element: Slack::UI::BlockElements::PlainTextInput.new(action_id: "reason"), block_id: "request.reason", optional: true, dispatch_action: true)
    end
    JSON.parse(modal.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/phase_3_form_modal.json"))
  end

  it "supports a display modal with optional submit and no invented minimum block count" do
    modal = Slack::UI.display_modal(title: Slack::UI.plain("Display")) { |_builder| }
    JSON.parse(modal.to_json).should eq JSON.parse(%({"type":"modal","title":{"type":"plain_text","text":"Display"},"blocks":[]}))
    submitted = Slack::UI.display_modal(title: Slack::UI.plain("Display"), submit: Slack::UI.plain("Done")) { |builder| builder.divider }
    submitted.submit.try(&.text).should eq "Done"
  end

  [0, 1, 99, 100, 101].each do |size|
    it "checks #{size} blocks on both surfaces" do
      blocks = Array.new(size) { Slack::UI::Blocks::Divider.new }
      if size <= 100
        Slack::UI::DisplayModal.new(title: Slack::UI.plain("Display"), blocks: blocks).blocks.size.should eq size
        Slack::UI::FormModal.new(title: Slack::UI.plain("Form"), submit: Slack::UI.plain("Send"), blocks: blocks).blocks.size.should eq size
      else
        error = expect_raises(Slack::UI::ValidationError) { Slack::UI::DisplayModal.new(title: Slack::UI.plain("Display"), blocks: blocks) }
        error.issues.map(&.code).should eq ["modal.blocks.too_many"]
        expect_raises(Slack::UI::ValidationError) { Slack::UI::FormModal.new(title: Slack::UI.plain("Form"), submit: Slack::UI.plain("Send"), blocks: blocks) }
      end
    end
  end

  it "checks every envelope length and counts characters" do
    Slack::UI::FormModal.new(blocks: [] of Slack::UI::ModalBlock,
      title: Slack::UI.plain("界" * 24), submit: Slack::UI.plain("界" * 24), close: Slack::UI.plain("界" * 24),
      private_metadata: "界" * 3000, callback_id: "界" * 255, external_id: "界" * 255).validate.should be_empty
    error = expect_raises(Slack::UI::ValidationError) do
      Slack::UI::FormModal.new(blocks: [] of Slack::UI::ModalBlock,
        title: Slack::UI.plain("界" * 25), submit: Slack::UI.plain("界" * 25), close: Slack::UI.plain("界" * 25),
        private_metadata: "界" * 3001, callback_id: "界" * 256, external_id: "界" * 256)
    end
    error.issues.map(&.code).should eq %w[modal.title.too_long modal.submit.too_long modal.close.too_long modal.private_metadata.too_long modal.callback_id.too_long modal.external_id.too_long]
  end

  it "checks duplicate IDs across block types and duplicate focus across the view" do
    error = expect_raises(Slack::UI::ValidationError) do
      Slack::UI.form_modal(title: Slack::UI.plain("Form"), submit: Slack::UI.plain("Send")) do |builder|
        builder.divider(block_id: "same")
        builder.input(label: Slack::UI.plain("First"), block_id: "same", element: Slack::UI::BlockElements::PlainTextInput.new(focus_on_load: true))
        builder.input(label: Slack::UI.plain("Second"), element: Slack::UI::BlockElements::PlainTextInput.new(focus_on_load: true))
      end
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"modal.block_id.duplicate", "blocks[1].block_id"},
      {"modal.focus_on_load.duplicate", "blocks[2].element.focus_on_load"},
    ]
  end

  it "permits omitted block IDs, repeated action IDs in different inputs, and explicit false focus" do
    Slack::UI.form_modal(title: Slack::UI.plain("Form"), submit: Slack::UI.plain("Send")) do |builder|
      [nil, false, true].each do |focus|
        builder.input(label: Slack::UI.plain("Input"), element: Slack::UI::BlockElements::PlainTextInput.new(action_id: "same", focus_on_load: focus))
      end
    end.validate.should be_empty
  end

  it "copies caller blocks and recursively protects input dispatch configuration" do
    triggers = [Slack::UI::CompositionObjects::DispatchTrigger::OnEnterPressed]
    input = Slack::UI::Blocks::Input.new(label: Slack::UI.plain("Input"), element: Slack::UI::BlockElements::PlainTextInput.new(
      dispatch_action_config: Slack::UI::CompositionObjects::DispatchActionConfig.new(trigger_actions_on: triggers)))
    blocks = [input]
    modal = Slack::UI::FormModal.new(title: Slack::UI.plain("Form"), submit: Slack::UI.plain("Send"), blocks: blocks)
    before = modal.to_json
    blocks.clear
    modal.blocks.clear
    triggers.clear
    case element = input.element
    when Slack::UI::BlockElements::PlainTextInput
      element.dispatch_action_config.try(&.trigger_actions_on.try(&.clear))
    end
    modal.to_json.should eq before
  end

  it "keeps snapshots stable after reuse of either builder" do
    display = Slack::UI::DisplayModalBuilder.new(title: Slack::UI.plain("Display"))
    form = Slack::UI::FormModalBuilder.new(title: Slack::UI.plain("Form"), submit: Slack::UI.plain("Send"))
    {display, form}.each do |builder|
      builder.section(Slack::UI.plain("Before"))
      snapshot = builder.build
      before = snapshot.to_json
      builder.divider
      snapshot.blocks.clear
      snapshot.to_json.should eq before
      builder.build.blocks.size.should eq 2
    end
  end
end

require "../../spec_helper"
require "../../support/block_kit/home_fixture"

private alias HomeUI = Slack::UI::Checked

describe HomeUI::Home do
  it "serializes a complete Home envelope including dispatched plain text input" do
    view = HomeFixture.builder.build
    JSON.parse(view.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/phase_4_views_publish.json"))["view"]
    view.validate.should be_empty
  end

  it "omits absent metadata and permits empty Home views" do
    view = HomeUI.home { |_builder| }
    JSON.parse(view.to_json).should eq JSON.parse(%({"type":"home","blocks":[]}))
    view = HomeUI.home(private_metadata: "", callback_id: "", external_id: "") { |_builder| }
    JSON.parse(view.to_json).should eq JSON.parse(%({"type":"home","blocks":[],"private_metadata":"","callback_id":"","external_id":""}))
  end

  [0, 1, 99, 100, 101].each do |size|
    it "validates #{size} Home blocks" do
      blocks = Array.new(size) { HomeUI::Blocks::Divider.new }
      if size <= 100
        HomeUI::Home.new(blocks: blocks).blocks.size.should eq size
      else
        error = expect_raises(HomeUI::ValidationError) { HomeUI::Home.new(blocks: blocks) }
        error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"home.blocks.too_many", "blocks"}]
      end
    end
  end

  it "validates documented metadata limits by characters" do
    HomeUI.home(private_metadata: "界" * 3000, callback_id: "界" * 255) { |_builder| }.validate.should be_empty
    error = expect_raises(HomeUI::ValidationError) { HomeUI.home(private_metadata: "界" * 3001, callback_id: "界" * 256) { |_builder| } }
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"home.private_metadata.too_long", "private_metadata"}, {"home.callback_id.too_long", "callback_id"}]
  end

  it "checks duplicate IDs across display and input blocks and duplicate input focus" do
    error = expect_raises(HomeUI::ValidationError) do
      HomeUI.home do |builder|
        builder.header(text: HomeUI.plain("Notes"), block_id: "same")
        builder.context(elements: [HomeUI.plain("Context")], block_id: "same")
        builder.input(label: HomeUI.plain("First"), block_id: "same", element: HomeUI::BlockElements::PlainTextInput.new(focus_on_load: true))
        builder.input(label: HomeUI.plain("Second"), element: HomeUI::BlockElements::PlainTextInput.new(focus_on_load: true))
      end
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"home.block_id.duplicate", "blocks[1].block_id"}, {"home.block_id.duplicate", "blocks[2].block_id"},
      {"home.focus_on_load.duplicate", "blocks[3].element.focus_on_load"},
    ]
  end

  it "allows omitted IDs, repeated action IDs across blocks, and optional input flags" do
    view = HomeUI.home do |builder|
      [nil, false, true].each do |flag|
        builder.input(label: HomeUI.plain("Note"), optional: flag, dispatch_action: flag,
          element: HomeUI::BlockElements::PlainTextInput.new(action_id: "text", focus_on_load: flag))
      end
    end
    blocks = JSON.parse(view.to_json)["blocks"]
    blocks[0].as_h.has_key?("optional").should be_false
    blocks[0].as_h.has_key?("dispatch_action").should be_false
    blocks[1]["optional"].as_bool.should be_false
    blocks[1]["dispatch_action"].as_bool.should be_false
    blocks[2]["dispatch_action"].as_bool.should be_true
  end

  it "protects nested dispatch arrays, caller collections, and retained builders" do
    triggers = [HomeUI::CompositionObjects::DispatchTrigger::OnEnterPressed]
    input = HomeUI::Blocks::Input.new(label: HomeUI.plain("Note"), element: HomeUI::BlockElements::PlainTextInput.new(
      dispatch_action_config: HomeUI::CompositionObjects::DispatchActionConfig.new(trigger_actions_on: triggers)))
    blocks = [input]
    builder = HomeUI::HomeBuilder.new
    builder.add_all(blocks)
    view = builder.build
    before = view.to_json
    blocks.clear
    triggers.clear
    input.element.dispatch_action_config.try(&.trigger_actions_on.try(&.clear))
    view.blocks.clear
    builder.divider
    view.snapshot.to_json.should eq before
    builder.build.blocks.size.should eq 2
  end
end

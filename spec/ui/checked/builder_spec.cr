require "../../spec_helper"

private alias BuilderUI = Slack::UI::Checked

describe "Checked builder composition" do
  it "preserves display arguments, block order, and snapshots on every surface" do
    builders = {
      BuilderUI::MessageBuilder.new(fallback_text: "Summary"),
      BuilderUI::DisplayModalBuilder.new(title: BuilderUI.plain("Summary")),
      BuilderUI::FormModalBuilder.new(title: BuilderUI.plain("Summary"), submit: BuilderUI.plain("Save")),
      BuilderUI::HomeBuilder.new,
    }
    button = BuilderUI::BlockElements::Button.new(text: BuilderUI.plain("Open"), action_id: "open")
    builders.each do |builder|
      elements = [button]
      builder.section(BuilderUI.mrkdwn("*Summary*"), button, "summary", false)
      builder.actions(elements, "controls")
      builder.divider("end")
      snapshot = builder.build
      before = snapshot.to_json
      JSON.parse(before)["blocks"].should eq JSON.parse(<<-JSON)
        [{"type":"section","text":{"type":"mrkdwn","text":"*Summary*"},"accessory":{"type":"button","text":{"type":"plain_text","text":"Open"},"action_id":"open"},"block_id":"summary","expand":false},
         {"type":"actions","elements":[{"type":"button","text":{"type":"plain_text","text":"Open"},"action_id":"open"}],"block_id":"controls"},
         {"type":"divider","block_id":"end"}]
        JSON
      elements.clear
      builder.section(text: BuilderUI.plain("Later"), accessory: nil)
      snapshot.to_json.should eq before
      later = JSON.parse(builder.build.to_json)["blocks"][3]
      later.should eq JSON.parse(%({"type":"section","text":{"type":"plain_text","text":"Later"}}))
    end
  end

  it "rejects invalid display additions before changing any builder" do
    builders = {
      BuilderUI::MessageBuilder.new(fallback_text: "Summary"),
      BuilderUI::DisplayModalBuilder.new(title: BuilderUI.plain("Summary")),
      BuilderUI::FormModalBuilder.new(title: BuilderUI.plain("Summary"), submit: BuilderUI.plain("Save")),
      BuilderUI::HomeBuilder.new,
    }
    builders.each do |builder|
      builder.divider("before")
      before = builder.build.to_json
      actions_error = expect_raises(BuilderUI::ValidationError) do
        builder.actions([] of BuilderUI::Blocks::Actions::Element, block_id: "x" * 256)
      end
      actions_error.issues.map { |issue| {issue.code, issue.path, issue.message} }.should eq [
        {"actions.elements.empty", "elements", "Elements must contain at least one element."},
        {"actions.block_id.too_long", "block_id", "Block ID cannot be longer than 255 characters."},
      ]
      expect_raises(BuilderUI::ValidationError) { builder.section(BuilderUI.plain("Valid"), block_id: "x" * 256) }
      expect_raises(BuilderUI::ValidationError) { builder.divider("x" * 256) }
      builder.build.to_json.should eq before
      builder.divider("after")
      builder.build.blocks.map(&.block_id).should eq ["before", "after"]
    end
  end

  it "preserves every input element and absent, false, and true flags in both input builders" do
    option = BuilderUI::CompositionObjects::Option.new(text: BuilderUI.plain("One"), value: "one")
    elements = {
      BuilderUI::BlockElements::PlainTextInput.new,
      BuilderUI::BlockElements::StaticSelect.new(options: {option}),
      BuilderUI::BlockElements::MultiStaticSelect.new(options: {option}),
    }
    {BuilderUI::HomeBuilder.new, BuilderUI::FormModalBuilder.new(title: BuilderUI.plain("Form"), submit: BuilderUI.plain("Save"))}.each do |builder|
      elements.each_with_index do |element, index|
        {nil, false, true}.each do |flag|
          builder.input(BuilderUI.plain("Choose"), element, "input-#{index}-#{flag.inspect}", BuilderUI.plain("Help"), flag, flag)
        end
      end
      blocks = JSON.parse(builder.build.to_json)["blocks"].as_a
      elements.each_with_index do |element, index|
        {nil, false, true}.each_with_index do |flag, flag_index|
          expected = JSON.parse(element.to_json)
          block = blocks[index * 3 + flag_index]
          block["element"].should eq expected
          block["label"]["text"].as_s.should eq "Choose"
          block["hint"]["text"].as_s.should eq "Help"
          block["block_id"].as_s.should eq "input-#{index}-#{flag.inspect}"
          if flag.nil?
            block.as_h.has_key?("optional").should be_false
            block.as_h.has_key?("dispatch_action").should be_false
          else
            block["optional"].as_bool.should eq flag
            block["dispatch_action"].as_bool.should eq flag
          end
        end
      end
    end
  end

  it "rejects invalid input additions before changing either input builder" do
    {BuilderUI::HomeBuilder.new, BuilderUI::FormModalBuilder.new(title: BuilderUI.plain("Form"), submit: BuilderUI.plain("Save"))}.each do |builder|
      builder.divider("before")
      before = builder.build.to_json
      error = expect_raises(BuilderUI::ValidationError) do
        builder.input(label: BuilderUI.plain("x" * 2001), element: BuilderUI::BlockElements::PlainTextInput.new,
          block_id: "x" * 256, hint: BuilderUI.plain("x" * 2001))
      end
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"input.label.too_long", "label.text"}, {"input.block_id.too_long", "block_id"}, {"input.hint.too_long", "hint.text"},
      ]
      builder.build.to_json.should eq before
      builder.input(label: BuilderUI.plain("Choose"), element: BuilderUI::BlockElements::PlainTextInput.new)
      builder.build.blocks.map(&.type).should eq ["divider", "input"]
    end
  end
end

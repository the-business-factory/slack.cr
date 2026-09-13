require "../../spec_helper"

describe Slack::UI::Checked::BlockElements::PlainTextInput do
  it "omits optional fields and retains explicit false, zero, and empty initial text" do
    JSON.parse(Slack::UI::Checked::BlockElements::PlainTextInput.new.to_json).should eq JSON.parse(%({"type":"plain_text_input"}))
    element = Slack::UI::Checked::BlockElements::PlainTextInput.new(
      action_id: "reason", initial_value: "", multiline: false, min_length: 0,
      max_length: 3000, focus_on_load: false, placeholder: Slack::UI::Checked.plain("Reason", emoji: false),
      dispatch_action_config: Slack::UI::Checked::CompositionObjects::DispatchActionConfig.new(
        trigger_actions_on: {Slack::UI::Checked::CompositionObjects::DispatchTrigger::OnEnterPressed, Slack::UI::Checked::CompositionObjects::DispatchTrigger::OnCharacterEntered}
      )
    )
    JSON.parse(element.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/phase_3_plain_text_input.json"))
  end

  [0, 1, 2999, 3000].each do |minimum|
    it "accepts minimum #{minimum} with a matching maximum" do
      Slack::UI::Checked::BlockElements::PlainTextInput.new(min_length: minimum, max_length: 3000).validate.should be_empty
    end
  end

  [-1, 3001].each do |minimum|
    it "rejects minimum #{minimum}" do
      error = expect_raises(Slack::UI::Checked::ValidationError) { Slack::UI::Checked::BlockElements::PlainTextInput.new(min_length: minimum) }
      error.issues.map(&.code).should eq ["plain_text_input.min_length.out_of_range"]
    end
  end

  [1, 2999, 3000].each do |maximum|
    it "accepts maximum #{maximum}" do
      Slack::UI::Checked::BlockElements::PlainTextInput.new(max_length: maximum).validate.should be_empty
    end
  end

  [-1, 0, 3001].each do |maximum|
    it "rejects maximum #{maximum}" do
      error = expect_raises(Slack::UI::Checked::ValidationError) { Slack::UI::Checked::BlockElements::PlainTextInput.new(max_length: maximum) }
      error.issues.map(&.code).should eq ["plain_text_input.max_length.out_of_range"]
    end
  end

  it "rejects inverted length bounds, but does not invent an initial_value restriction" do
    error = expect_raises(Slack::UI::Checked::ValidationError) { Slack::UI::Checked::BlockElements::PlainTextInput.new(min_length: 3, max_length: 2) }
    error.issues.map(&.code).should eq ["plain_text_input.length.inverted"]
    Slack::UI::Checked::BlockElements::PlainTextInput.new(min_length: 2, initial_value: "").validate.should be_empty
    Slack::UI::Checked::BlockElements::PlainTextInput.new(max_length: 1, initial_value: "longer").validate.should be_empty
  end

  it "checks action and placeholder lengths in Unicode characters" do
    Slack::UI::Checked::BlockElements::PlainTextInput.new(action_id: "界" * 255, placeholder: Slack::UI::Checked.plain("界" * 150)).validate.should be_empty
    error = expect_raises(Slack::UI::Checked::ValidationError) do
      Slack::UI::Checked::BlockElements::PlainTextInput.new(action_id: "界" * 256, placeholder: Slack::UI::Checked.plain("界" * 151))
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"plain_text_input.action_id.too_long", "action_id"},
      {"plain_text_input.placeholder.too_long", "placeholder.text"},
    ]
  end
end

describe Slack::UI::Checked::CompositionObjects::DispatchActionConfig do
  it "supports omission and each individual trigger" do
    JSON.parse(Slack::UI::Checked::CompositionObjects::DispatchActionConfig.new.to_json).should eq JSON.parse("{}")
    Slack::UI::Checked::CompositionObjects::DispatchTrigger.each do |trigger|
      config = Slack::UI::Checked::CompositionObjects::DispatchActionConfig.new(trigger_actions_on: [trigger])
      JSON.parse(config.to_json)["trigger_actions_on"].as_a.map(&.as_s).should eq [trigger.wire_value]
    end
  end

  it "rejects empty, duplicate, too many, and unnamed triggers" do
    trigger = Slack::UI::Checked::CompositionObjects::DispatchTrigger::OnEnterPressed
    [
      [] of Slack::UI::Checked::CompositionObjects::DispatchTrigger,
      [trigger, trigger], [trigger, trigger, trigger],
      [Slack::UI::Checked::CompositionObjects::DispatchTrigger.new(99)],
    ].each do |triggers|
      expect_raises(Slack::UI::Checked::ValidationError) { Slack::UI::Checked::CompositionObjects::DispatchActionConfig.new(trigger_actions_on: triggers) }
    end
  end

  it "owns the trigger array and returns a copy" do
    triggers = [Slack::UI::Checked::CompositionObjects::DispatchTrigger::OnEnterPressed]
    config = Slack::UI::Checked::CompositionObjects::DispatchActionConfig.new(trigger_actions_on: triggers)
    before = config.to_json
    triggers.clear
    config.trigger_actions_on.try(&.clear)
    config.to_json.should eq before
  end
end

describe Slack::UI::Checked::Blocks::Input do
  it "serializes every field and omits absent options" do
    element = Slack::UI::Checked::BlockElements::PlainTextInput.new
    minimal = Slack::UI::Checked::Blocks::Input.new(label: Slack::UI::Checked.plain("Label"), element: element)
    JSON.parse(minimal.to_json).should eq JSON.parse(%({"type":"input","label":{"type":"plain_text","text":"Label"},"element":{"type":"plain_text_input"}}))
    input = Slack::UI::Checked::Blocks::Input.new(label: Slack::UI::Checked.plain("Label"), element: element,
      block_id: "reason", hint: Slack::UI::Checked.plain("Hint"), optional: false, dispatch_action: false)
    JSON.parse(input.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/phase_3_input.json"))
  end

  it "checks the label, hint, and block ID boundaries together" do
    element = Slack::UI::Checked::BlockElements::PlainTextInput.new
    Slack::UI::Checked::Blocks::Input.new(label: Slack::UI::Checked.plain("界" * 2000), hint: Slack::UI::Checked.plain("界" * 2000), block_id: "界" * 255, element: element).validate.should be_empty
    error = expect_raises(Slack::UI::Checked::ValidationError) do
      Slack::UI::Checked::Blocks::Input.new(label: Slack::UI::Checked.plain("界" * 2001), hint: Slack::UI::Checked.plain("界" * 2001), block_id: "界" * 256, element: element)
    end
    error.issues.map(&.code).should eq ["input.label.too_long", "input.block_id.too_long", "input.hint.too_long"]
  end
end

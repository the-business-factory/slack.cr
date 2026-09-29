require "../spec_helper"

describe "received checkbox selections" do
  it "decodes checked actions and cleared state while preserving unknown data" do
    interaction = Slack::Interaction.from_json(File.read("spec/fixtures/block_kit/checkboxes_action.json")).should be_a(Slack::Interactions::BlockAction)
    action = interaction.decoded_actions.first.should be_a(Slack::Interactions::CheckboxesAction)
    action.type.should eq "checkboxes"
    action.block_id.should eq "preferences"
    action.action_id.should eq "notifications"
    action.action_ts.should eq "1710000000.000001"
    selected = action.selected_options.should_not be_nil
    selected.map(&.value).should eq ["digest"]
    selected[0].text.should eq "*Daily digest*"
    selected[0].text_type.should eq "mrkdwn"
    selected[0].description.try(&.text).should eq "_Once a day_"
    selected[0].raw["text"]["future_text"].as_bool.should be_false
    selected[0].raw["future_option"].as_a.should be_empty
    action.raw["future_action"].as_bool.should be_false
    selected.clear
    action.selected_options.try(&.size).should eq 1
    unknown = interaction.decoded_actions.last.should be_a(Slack::Interactions::UnknownAction)
    unknown.raw.should eq JSON.parse(%({"type":"future_choice","selected_options":[],"extra":null}))
    state = interaction.state_map.checkboxes_value?("preferences", "notifications").should_not be_nil
    state.selected_options.should eq [] of Slack::Interactions::SelectedOption
    state.selected_options_presence.should eq Slack::Interactions::ValuePresence::Present
    state.raw["future_state"].should eq "kept"
  end

  it "distinguishes absent, null, and cleared selections in actions and submissions" do
    {"" => Slack::Interactions::ValuePresence::Absent, "null" => Slack::Interactions::ValuePresence::Null, "[]" => Slack::Interactions::ValuePresence::Present}.each do |value, presence|
      field = value.empty? ? "" : %(,"selected_options":#{value})
      actions = Slack::Interactions::ActionDecoder.decode(JSON.parse(%([{"type":"checkboxes","block_id":"b","action_id":"a"#{field}}])))
      action = actions.first.should be_a(Slack::Interactions::CheckboxesAction)
      action.selected_options_presence.should eq presence
      action.selected_options.should eq(presence.present? ? [] of Slack::Interactions::SelectedOption : nil)
      action.action_ts.should be_nil
      submission = Slack::Interaction.from_json(%({"type":"view_submission","view":{"state":{"values":{"b":{"a":{"type":"checkboxes"#{field}}}}}}})).should be_a(Slack::Interactions::ViewSubmission)
      state = submission.state_map.checkboxes_value?("b", "a").should_not be_nil
      state.selected_options_presence.should eq presence
      state.selected_options.should eq action.selected_options
      submission.state_map.checkboxes_value?("b", "missing").should be_nil
    end
  end

  it "reports malformed known values on typed access while retaining raw data" do
    base = JSON.parse(File.read("spec/fixtures/block_kit/checkboxes_action.json"))["actions"][0]
    {"selected_options" => JSON.parse("false"), "action_id" => JSON.parse("42"), "block_id" => JSON.parse("[]"), "action_ts" => JSON.parse("{}")}.each do |field, value|
      raw = base.as_h.dup
      raw[field] = value
      interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
      interaction.actions.should eq JSON.parse([raw].to_json)
      expect_raises(Slack::Interactions::TypeMismatch) { interaction.decoded_actions }.path.should eq "actions[0].#{field}"
    end
    {"null" => "", "{}" => ".value", %({"value":"x","text":{"type":"mrkdwn","text":false}}) => ".text.text"}.each do |option, suffix|
      map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"a":{"type":"checkboxes","selected_options":[#{option}]}}}})))
      expect_raises(Slack::Interactions::TypeMismatch) { map.checkboxes_value?("b", "a") }.path.should eq %(state.values["b"]["a"].selected_options[0]#{suffix})
    end
    wrong = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"a":{"type":"multi_static_select","selected_options":[]}}}})))
    expect_raises(Slack::Interactions::TypeMismatch) { wrong.checkboxes_value?("b", "a") }.path.should eq %(state.values["b"]["a"])
  end

  it "does not apply outbound option counts, lengths, or formats to received choices" do
    options = Array.new(11) { {text: {type: "future_text", text: "界" * 76}, value: "界" * 151} }
    value = Slack::Interactions::CheckboxesValue.new(JSON.parse({type: "checkboxes", selected_options: options}.to_json), "state")
    selected = value.selected_options.should_not be_nil
    selected.size.should eq 11
    selected.first.text_type.should eq "future_text"
    selected.first.value.size.should eq 151
    expect_raises(Slack::Interactions::TypeMismatch) { Slack::Interactions::CheckboxesValue.new(JSON.parse(%({"type":"radio_buttons"})), "state") }.path.should eq "state.type"
  end
end

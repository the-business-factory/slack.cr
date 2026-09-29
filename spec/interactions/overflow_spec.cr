require "../spec_helper"

describe "received Overflow actions" do
  it "decodes a received selection and retains unknown action, option, and text fields" do
    interaction = Slack::Interaction.from_json(File.read("spec/fixtures/block_kit/overflow_action.json")).should be_a(Slack::Interactions::BlockAction)
    action = interaction.actions.first.should be_a(Slack::Interactions::OverflowAction)
    action.type.should eq "overflow"
    action.action_id.should eq "request.more"
    action.block_id.should eq "request"
    action.action_ts.should eq "1710000000.000001"
    action.selected_option.value.should eq "details"
    action.selected_option.text.should eq "Details"
    action.selected_option.text_type.should eq "plain_text"
    action.selected_option.url.should eq "https://example.com/requests/42"
    unknown = interaction.actions.last.should be_a(Slack::Interactions::UnknownAction)
    unknown.raw.should eq JSON.parse(%({"type":"future_overflow","value":null}))
  end

  it "reports malformed known fields on typed access without losing the raw action" do
    base = JSON.parse(File.read("spec/fixtures/block_kit/overflow_action.json"))["actions"][0]
    {"selected_option" => JSON.parse("null"), "action_id" => JSON.parse("42"), "block_id" => JSON.parse("false"), "action_ts" => JSON.parse("[]")}.each do |field, value|
      raw = base.as_h.dup
      raw[field] = value
      interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
      JSON.parse(interaction.to_json)["actions"].should eq JSON.parse([raw].to_json)
      expect_raises(Slack::Interactions::TypeMismatch) { interaction.actions }.path.should eq "actions[0].#{field}"
    end
    {"{}" => "value", %({"value":"x","text":null}) => "text"}.each do |option, suffix|
      raw = base.as_h.dup
      raw["selected_option"] = JSON.parse(option)
      expect_raises(Slack::Interactions::TypeMismatch) { Slack::Interactions::ActionDecoder.decode(JSON.parse([raw].to_json)) }.path.should eq "actions[0].selected_option.#{suffix}"
    end
    missing = base.as_h.dup
    missing.delete("selected_option")
    expect_raises(Slack::Interactions::TypeMismatch) { Slack::Interactions::ActionDecoder.decode(JSON.parse([missing].to_json)) }.path.should eq "actions[0].selected_option"
  end

  it "does not impose outbound limits or text formats on received selections" do
    raw = JSON.parse({type: "overflow", block_id: "", action_id: "", selected_option: {text: {type: "future_text", text: "界" * 76}, value: ""}}.to_json)
    action = Slack::Interactions::OverflowAction.new(raw)
    action.selected_option.text.size.should eq 76
    action.selected_option.text_type.should eq "future_text"
    action.selected_option.value.should eq ""
    action.action_ts.should be_nil
    expect_raises(Slack::Interactions::TypeMismatch) { Slack::Interactions::OverflowAction.new(JSON.parse(%({"type":"static_select"}))) }.path.should eq "action.type"
  end
end

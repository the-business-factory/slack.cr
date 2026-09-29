require "../spec_helper"

private def context_clicks_fixture : JSON::Any
  JSON.parse(File.read("spec/fixtures/interactions/block_actions_context_clicks.json"))
end

private def decode_single(action : Hash(String, JSON::Any)) : Slack::Interactions::Action
  Slack::Interactions::ActionDecoder.decode(JSON.parse([action].to_json)).first
end

describe "received feedback, icon, and workflow button clicks" do
  it "decodes SDK-shaped clicks and keeps unlisted action types unknown" do
    interaction = Slack::Interaction.from_json(context_clicks_fixture.to_json).should be_a(Slack::Interactions::BlockAction)
    actions = interaction.actions

    feedback = actions[0].should be_a(Slack::Interactions::FeedbackButtonsAction)
    feedback.type.should eq "feedback_buttons"
    feedback.action_id.should eq "answer.feedback"
    feedback.block_id.should eq "answer.actions"
    feedback.action_ts.should eq "1710000001.000100"
    feedback.value.should eq "good"
    feedback_text = feedback.text.should_not be_nil
    feedback_text.text.should eq "Good"
    feedback_text.emoji.should be_true

    icon = actions[1].should be_a(Slack::Interactions::IconButtonAction)
    icon.type.should eq "icon_button"
    icon.action_id.should eq "answer.delete"
    icon.action_ts.should eq "1710000001.000200"
    icon.icon.should eq "trash"
    icon.value.should eq "delete"
    icon.text.try(&.text).should eq "Delete"

    workflow = actions[2].should be_a(Slack::Interactions::WorkflowButtonAction)
    workflow.type.should eq "workflow_button"
    workflow.action_id.should eq "postmortem.start"
    workflow.block_id.should eq "incident"
    workflow.text.try(&.text).should eq "Start postmortem"
    workflow.workflow.should eq JSON.parse(<<-JSON)
      {"trigger":{"url":"https://slack.com/shortcuts/Ft0SYNTHETIC/postmortem",
                  "customizable_input_parameters":[{"name":"incident_id","value":"INC-7"}]}}
      JSON

    unknown = actions[3].should be_a(Slack::Interactions::UnknownAction)
    unknown.type.should eq "future_click"
    unknown.raw.should eq JSON.parse(%({"type":"future_click","block_id":"answer.actions","action_id":"answer.future","value":3}))
  end

  it "decodes a click that carries only the common action fields" do
    {"feedback_buttons", "icon_button", "workflow_button"}.each do |type|
      action = decode_single({"type" => JSON::Any.new(type), "block_id" => JSON::Any.new("b"), "action_id" => JSON::Any.new("a")})
      case action
      when Slack::Interactions::FeedbackButtonsAction
        {action.value, action.text, action.action_ts}.should eq({nil, nil, nil})
      when Slack::Interactions::IconButtonAction
        {action.icon, action.value, action.text, action.action_ts}.should eq({nil, nil, nil, nil})
      when Slack::Interactions::WorkflowButtonAction
        {action.workflow, action.text, action.action_ts}.should eq({nil, nil, nil})
      else
        fail("Expected a typed #{type} action, got #{action.class}")
      end
    end
  end

  it "reports malformed known fields with the action path" do
    actions = context_clicks_fixture["actions"].as_a
    {
      {actions[0], "value", JSON.parse("1")},
      {actions[0], "text", JSON.parse(%("Good"))},
      {actions[1], "icon", JSON.parse("{}")},
      {actions[1], "action_id", JSON.parse("null")},
      {actions[2], "workflow", JSON.parse(%("https://slack.com/shortcuts/Ft0SYNTHETIC/postmortem"))},
      {actions[2], "block_id", JSON.parse("false")},
    }.each do |action, field, value|
      raw = action.as_h.dup
      raw[field] = value
      interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
      expect_raises(Slack::Interactions::TypeMismatch) { interaction.actions }.path.should eq "actions[0].#{field}"
    end
  end

  it "checks the discriminator when callers construct a click directly" do
    raw = context_clicks_fixture["actions"][0]
    expect_raises(Slack::Interactions::TypeMismatch, "action.type: expected icon_button, got feedback_buttons") do
      Slack::Interactions::IconButtonAction.new(raw)
    end
    expect_raises(Slack::Interactions::TypeMismatch, "action.type: expected workflow_button, got feedback_buttons") do
      Slack::Interactions::WorkflowButtonAction.new(raw)
    end
    expect_raises(Slack::Interactions::TypeMismatch, "action.type: expected feedback_buttons, got icon_button") do
      Slack::Interactions::FeedbackButtonsAction.new(context_clicks_fixture["actions"][1])
    end
  end
end

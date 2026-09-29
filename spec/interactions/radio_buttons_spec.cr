require "../spec_helper"

describe "received radio selections" do
  it "decodes an independently authored action and state with unknown fields" do
    interaction = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::BlockAction)
      {"type":"block_actions","actions":[
        {"type":"radio_buttons","block_id":"preferences","action_id":"delivery","action_ts":"1710000000.000001",
         "selected_option":{"text":{"type":"mrkdwn","text":"*Digest*","future_text":false},"value":"digest","description":{"type":"mrkdwn","text":"_Daily_"},"future_option":[]},"future_action":false},
        {"type":"future_choice","selected_option":null,"extra":[]}],
       "state":{"values":{"preferences":{"delivery":{"type":"radio_buttons","selected_option":{"text":{"type":"plain_text","text":"Immediate"},"value":"immediate"},"future_state":"kept"},"future":{"type":"future_choice","extra":null}}}}}
      JSON
    action = interaction.decoded_actions.first.should be_a(Slack::Interactions::RadioButtonsAction)
    action.type.should eq "radio_buttons"
    action.block_id.should eq "preferences"
    action.action_id.should eq "delivery"
    action.action_ts.should eq "1710000000.000001"
    action.selected_option_presence.should eq Slack::Interactions::ValuePresence::Present
    selected = action.selected_option.should_not be_nil
    selected.value.should eq "digest"
    selected.text.should eq "*Digest*"
    selected.text_type.should eq "mrkdwn"
    selected.description.try(&.text).should eq "_Daily_"
    selected.raw["text"]["future_text"].as_bool.should be_false
    selected.raw["future_option"].as_a.should be_empty
    action.raw["future_action"].as_bool.should be_false
    unknown = interaction.decoded_actions.last.should be_a(Slack::Interactions::UnknownAction)
    unknown.raw.should eq JSON.parse(%({"type":"future_choice","selected_option":null,"extra":[]}))
    state = interaction.state_map.radio_buttons_value?("preferences", "delivery").should_not be_nil
    state.selected_option.try(&.value).should eq "immediate"
    state.selected_option_presence.should eq Slack::Interactions::ValuePresence::Present
    state.raw["future_state"].should eq "kept"
    unknown_state = interaction.state_map["preferences", "future"]?.should be_a(Slack::Interactions::UnknownStateValue)
    unknown_state.raw.should eq JSON.parse(%({"type":"future_choice","extra":null}))
  end

  it "distinguishes absent, null, and selected options in actions and submissions" do
    {""                                                      => Slack::Interactions::ValuePresence::Absent,
     "null"                                                  => Slack::Interactions::ValuePresence::Null,
     %({"text":{"type":"plain_text","text":"X"},"value":""}) => Slack::Interactions::ValuePresence::Present}.each do |value, presence|
      field = value.empty? ? "" : %(,"selected_option":#{value})
      actions = Slack::Interactions::ActionDecoder.decode(JSON.parse(%([{"type":"radio_buttons","block_id":"b","action_id":"a"#{field}}])))
      action = actions.first.should be_a(Slack::Interactions::RadioButtonsAction)
      action.selected_option_presence.should eq presence
      action.selected_option.try(&.value).should eq(presence.present? ? "" : nil)
      action.action_ts.should be_nil
      submission = Slack::Interaction.from_json(%({"type":"view_submission","view":{"state":{"values":{"b":{"a":{"type":"radio_buttons"#{field}}}}}}})).should be_a(Slack::Interactions::ViewSubmission)
      state = submission.state_map.radio_buttons_value?("b", "a").should_not be_nil
      state.selected_option_presence.should eq presence
      state.selected_option.should eq action.selected_option
      submission.state_map.radio_buttons_value?("b", "missing").should be_nil
      view = submission.view.should_not be_nil
      view.state_map.radio_buttons_value?("b", "a").should eq state
    end
  end

  it "reports malformed known fields on typed access and preserves the raw payload" do
    {
      %({"selected_option":[]})                                                  => "selected_option",
      %({"selected_option":false})                                               => "selected_option",
      %({"selected_option":{}})                                                  => "selected_option.value",
      %({"selected_option":{"value":"x","text":{"type":"mrkdwn","text":false}}}) => "selected_option.text.text",
      %({"action_id":42})                                                        => "action_id",
      %({"block_id":[]})                                                         => "block_id",
      %({"action_ts":{}})                                                        => "action_ts",
    }.each do |override, suffix|
      raw = JSON.parse(%({"type":"radio_buttons","block_id":"b","action_id":"a"})).as_h.merge(JSON.parse(override).as_h)
      interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
      interaction.actions.should eq JSON.parse([raw].to_json)
      expect_raises(Slack::Interactions::TypeMismatch) { interaction.decoded_actions }.path.should eq "actions[0].#{suffix}"
      if suffix.starts_with?("selected_option")
        map = Slack::Interactions::StateMap.new(JSON.parse({values: {b: {a: raw}}}.to_json))
        expect_raises(Slack::Interactions::TypeMismatch) { map.radio_buttons_value?("b", "a") }.path.should eq %(state.values["b"]["a"].#{suffix})
      end
    end
    wrong = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"a":{"type":"static_select","selected_option":null}}}})))
    expect_raises(Slack::Interactions::TypeMismatch) { wrong.radio_buttons_value?("b", "a") }.path.should eq %(state.values["b"]["a"])
  end

  it "does not apply outbound option lengths or formats to received data" do
    option = {text: {type: "future_text", text: "界" * 76}, value: "界" * 151}
    raw = JSON.parse({type: "radio_buttons", selected_option: option}.to_json)
    value = Slack::Interactions::RadioButtonsValue.new(raw, "state")
    selected = value.selected_option.should_not be_nil
    selected.text_type.should eq "future_text"
    selected.text.size.should eq 76
    selected.value.size.should eq 151
    selected.raw.should eq JSON.parse(option.to_json)
    expect_raises(Slack::Interactions::TypeMismatch) { Slack::Interactions::RadioButtonsValue.new(JSON.parse(%({"type":"checkboxes"})), "state") }.path.should eq "state.type"
  end
end

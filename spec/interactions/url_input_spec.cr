require "../spec_helper"

describe "received URL inputs" do
  it "decodes an independently authored dispatched action and view state" do
    interaction = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::BlockAction)
      {"type":"block_actions","actions":[
       {"type":"url_text_input","block_id":"link","action_id":"url","action_ts":"1710000000.000001","value":"https://example.com/a","future":true}],
       "view":{"state":{"values":{"link":{"url":{"type":"url_text_input","value":"https://example.com/draft","future":{}}}}}},
       "state":{"values":{"link":{"url":{"type":"url_text_input","value":"https://example.com/a"}}}}}
      JSON
    action = interaction.decoded_actions.first.should be_a(Slack::Interactions::UrlInputAction)
    action.value.should eq "https://example.com/a"
    action.value_presence.present?.should be_true
    action.block_id.should eq "link"
    action.action_id.should eq "url"
    action.action_ts.should eq "1710000000.000001"
    action.type.should eq "url_text_input"
    action.raw["future"].as_bool.should be_true
    interaction.state_map.url_input_value?("link", "url").should_not(be_nil).value.should eq "https://example.com/a"
    view_state = interaction.view.should_not(be_nil).state_map.url_input_value?("link", "url").should_not be_nil
    view_state.value.should eq "https://example.com/draft"
    view_state.raw["future"].as_h.should be_empty
  end

  it "preserves absent, cleared, and present values and rejects the wrong family" do
    {"", "null", %q(""), %q("not a url")}.each do |value|
      field = value.empty? ? "" : %(,"value":#{value})
      payload = %({"type":"view_submission","view":{"state":{"values":{"link":{"url":{"type":"url_text_input"#{field}},"note":{"type":"plain_text_input","value":"x"}}}}}})
      state = Slack::Interaction.from_json(payload).should(be_a(Slack::Interactions::ViewSubmission)).state_map
      url = state.url_input_value?("link", "url").should_not be_nil
      presence = value.empty? ? Slack::Interactions::ValuePresence::Absent : value == "null" ? Slack::Interactions::ValuePresence::Null : Slack::Interactions::ValuePresence::Present
      url.value_presence.should eq presence
      url.value.should eq(presence.present? ? JSON.parse(value).as_s : nil)
      action = Slack::Interactions::ActionDecoder.decode(JSON.parse(%([{"type":"url_text_input","block_id":"b","action_id":"a"#{field}}]))).first
      action.should(be_a(Slack::Interactions::UrlInputAction)).value_presence.should eq presence
      state.url_input_value?("link", "missing").should be_nil
      expect_raises(Slack::Interactions::TypeMismatch) { state.url_input_value?("link", "note") }.path.should eq %(view.state.values["link"]["note"])
      expect_raises(Slack::Interactions::TypeMismatch) { state.plain_text?("link", "url") }
    end
  end

  it "rejects wrong JSON types with paths while keeping the raw payload available" do
    {"value" => "12", "action_id" => "false", "block_id" => "[]", "action_ts" => "1"}.each do |field, value|
      raw = JSON.parse(%({"type":"url_text_input","block_id":"b","action_id":"a"})).as_h
      raw[field] = JSON.parse(value)
      interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
      interaction.actions.should eq JSON.parse([raw].to_json)
      expect_raises(Slack::Interactions::TypeMismatch) { interaction.decoded_actions }.path.should eq "actions[0].#{field}"
    end
    map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"a":{"type":"url_text_input","value":["https://x"]}}}})))
    expect_raises(Slack::Interactions::TypeMismatch) { map["b", "a"]? }.path.should eq %(state.values["b"]["a"].value)
  end
end

require "../spec_helper"

describe "received conversation selections" do
  it "decodes independent actions and full state while preserving unknown data" do
    interaction = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::BlockAction)
      {"type":"block_actions","actions":[
        {"type":"conversations_select","block_id":"notifications","action_id":"notification","action_ts":"1710000000.000001","selected_conversation":"D-NOTIFY","future":false},
        {"type":"multi_conversations_select","block_id":"notifications","action_id":"destinations","selected_conversations":["C-ONE","G-TWO"],"future":[]},
        {"type":"future_select","selected_conversations":[],"future":{"nested":null}}],
       "state":{"values":{"notifications":{
        "notification":{"type":"conversations_select","selected_conversation":"C-OTHER","future":[]},
        "destinations":{"type":"multi_conversations_select","selected_conversations":["C-DESTINATION"],"future":false},
        "unknown":{"type":"future_select","future":{"nested":null}}}}}}
      JSON
    actions = interaction.decoded_actions
    single = actions[0].should be_a(Slack::Interactions::ConversationsSelectAction)
    single.selected_conversation.should eq "D-NOTIFY"
    single.action_id.should eq "notification"
    single.block_id.should eq "notifications"
    single.action_ts.should eq "1710000000.000001"
    single.raw["future"].as_bool.should be_false
    multi = actions[1].should be_a(Slack::Interactions::MultiConversationsSelectAction)
    multi.selected_conversations.should eq ["C-ONE", "G-TWO"]
    multi.action_ts.should be_nil
    multi.selected_conversations.should_not(be_nil).clear
    multi.selected_conversations.should eq ["C-ONE", "G-TWO"]
    multi.raw["future"].as_a.should be_empty
    unknown = actions[2].should be_a(Slack::Interactions::UnknownAction)
    unknown.raw.should eq JSON.parse(%({"type":"future_select","selected_conversations":[],"future":{"nested":null}}))
    state = interaction.state_map
    state.conversations_select_value?("notifications", "notification").should_not(be_nil).selected_conversation.should eq "C-OTHER"
    destinations = state.multi_conversations_select_value?("notifications", "destinations").should_not be_nil
    destinations.selected_conversations.should eq ["C-DESTINATION"]
    destinations.raw["future"].as_bool.should be_false
    state["notifications", "unknown"]?.should(be_a(Slack::Interactions::UnknownStateValue)).raw.should eq JSON.parse(%({"type":"future_select","future":{"nested":null}}))
  end

  it "distinguishes missing entries, absent fields, null, and empty selections in actions and submissions" do
    {"conversations_select" => "selected_conversation", "multi_conversations_select" => "selected_conversations"}.each do |type, field|
      {"", "null", type == "conversations_select" ? %("") : "[]"}.each do |value|
        selection = value.empty? ? "" : %(,"#{field}":#{value})
        action_raw = JSON.parse(%([{"type":"#{type}","block_id":"b","action_id":"a"#{selection}}]))
        action = Slack::Interactions::ActionDecoder.decode(action_raw).first
        payload = %({"type":"view_submission","view":{"state":{"values":{"b":{"a":{"type":"#{type}"#{selection}}}}}}})
        submission = Slack::Interaction.from_json(payload).should be_a(Slack::Interactions::ViewSubmission)
        expected = value.empty? ? Slack::Interactions::ValuePresence::Absent : value == "null" ? Slack::Interactions::ValuePresence::Null : Slack::Interactions::ValuePresence::Present
        case action
        when Slack::Interactions::ConversationsSelectAction
          state = submission.state_map.conversations_select_value?("b", "a").should_not be_nil
          action.selected_conversation_presence.should eq expected
          state.selected_conversation_presence.should eq expected
          state.selected_conversation.should eq(expected.present? ? "" : nil)
        when Slack::Interactions::MultiConversationsSelectAction
          state = submission.state_map.multi_conversations_select_value?("b", "a").should_not be_nil
          action.selected_conversations_presence.should eq expected
          state.selected_conversations_presence.should eq expected
          state.selected_conversations.should eq(expected.present? ? [] of String : nil)
        else
          fail "Expected a typed conversation action"
        end
        submission.state_map["b", "missing"]?.should be_nil
        submission.view.should_not(be_nil).state_map["b", "a"]?.should eq submission.state_map["b", "a"]?
      end
    end
  end

  it "reports useful paths for malformed known action and state values" do
    {
      "conversations_select" => {
        %({"selected_conversation":[]})    => "selected_conversation",
        %({"selected_conversation":false}) => "selected_conversation",
        %({"action_id":42})                => "action_id",
      },
      "multi_conversations_select" => {
        %({"selected_conversations":{}})          => "selected_conversations",
        %({"selected_conversations":["C1",null]}) => "selected_conversations[1]",
        %({"selected_conversations":["C1",42]})   => "selected_conversations[1]",
        %({"block_id":[]})                        => "block_id",
        %({"action_ts":false})                    => "action_ts",
      },
    }.each do |type, cases|
      cases.each do |override, suffix|
        raw = JSON.parse(%({"type":"#{type}","block_id":"b","action_id":"a"})).as_h.merge(JSON.parse(override).as_h)
        interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
        interaction.actions.should eq JSON.parse([raw].to_json)
        expect_raises(Slack::Interactions::TypeMismatch) { interaction.decoded_actions }.path.should eq "actions[0].#{suffix}"
        if suffix.starts_with?("selected_")
          map = Slack::Interactions::StateMap.new(JSON.parse({values: {b: {a: raw}}}.to_json))
          expect_raises(Slack::Interactions::TypeMismatch) { map["b", "a"]? }.path.should eq %(state.values["b"]["a"].#{suffix})
        end
      end
    end
    map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"single":{"type":"conversations_select"},"multi":{"type":"multi_conversations_select"}}}})))
    expect_raises(Slack::Interactions::TypeMismatch) { map.conversations_select_value?("b", "multi") }.path.should eq %(state.values["b"]["multi"])
    expect_raises(Slack::Interactions::TypeMismatch) { map.multi_conversations_select_value?("b", "single") }.path.should eq %(state.values["b"]["single"])
  end

  it "does not impose outbound empty or distinct ID policies on received selections" do
    raw = JSON.parse(%({"type":"multi_conversations_select","selected_conversations":["","future-id","future-id"]}))
    value = Slack::Interactions::MultiConversationsSelectValue.new(raw, "state")
    value.selected_conversations.should eq ["", "future-id", "future-id"]
    expect_raises(Slack::Interactions::TypeMismatch) { Slack::Interactions::ConversationsSelectValue.new(raw, "state") }.path.should eq "state.type"
  end
end

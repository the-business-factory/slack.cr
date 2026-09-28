require "../spec_helper"

describe "received channel selections" do
  it "decodes independent actions and full state while preserving unknown data" do
    interaction = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::BlockAction)
      {"type":"block_actions","actions":[
        {"type":"channels_select","block_id":"notifications","action_id":"notification","action_ts":"1710000000.000001","selected_channel":"C-NOTIFY","future":false},
        {"type":"multi_channels_select","block_id":"notifications","action_id":"destinations","selected_channels":["C-ONE","C-TWO"],"future":[]},
        {"type":"future_select","selected_channels":[],"future":{"nested":null}}],
       "state":{"values":{"notifications":{
        "notification":{"type":"channels_select","selected_channel":"C-OTHER","future":[]},
        "destinations":{"type":"multi_channels_select","selected_channels":["C-DESTINATION"],"future":false},
        "unknown":{"type":"future_select","future":{"nested":null}}}}}}
      JSON
    actions = interaction.decoded_actions
    single = actions[0].should be_a(Slack::Interactions::ChannelsSelectAction)
    single.selected_channel.should eq "C-NOTIFY"
    single.action_id.should eq "notification"
    single.block_id.should eq "notifications"
    single.action_ts.should eq "1710000000.000001"
    single.raw["future"].as_bool.should be_false
    multi = actions[1].should be_a(Slack::Interactions::MultiChannelsSelectAction)
    multi.selected_channels.should eq ["C-ONE", "C-TWO"]
    multi.action_ts.should be_nil
    multi.selected_channels.should_not(be_nil).clear
    multi.selected_channels.should eq ["C-ONE", "C-TWO"]
    multi.raw["future"].as_a.should be_empty
    unknown = actions[2].should be_a(Slack::Interactions::UnknownAction)
    unknown.raw.should eq JSON.parse(%({"type":"future_select","selected_channels":[],"future":{"nested":null}}))
    state = interaction.state_map
    state.channels_select_value?("notifications", "notification").should_not(be_nil).selected_channel.should eq "C-OTHER"
    destinations = state.multi_channels_select_value?("notifications", "destinations").should_not be_nil
    destinations.selected_channels.should eq ["C-DESTINATION"]
    destinations.raw["future"].as_bool.should be_false
    state["notifications", "unknown"]?.should(be_a(Slack::Interactions::UnknownStateValue)).raw.should eq JSON.parse(%({"type":"future_select","future":{"nested":null}}))
  end

  it "distinguishes missing entries, absent fields, null, and empty selections in actions and submissions" do
    {"channels_select" => "selected_channel", "multi_channels_select" => "selected_channels"}.each do |type, field|
      {"", "null", type == "channels_select" ? %("") : "[]"}.each do |value|
        selection = value.empty? ? "" : %(,"#{field}":#{value})
        action_raw = JSON.parse(%([{"type":"#{type}","block_id":"b","action_id":"a"#{selection}}]))
        action = Slack::Interactions::ActionDecoder.decode(action_raw).first
        payload = %({"type":"view_submission","view":{"state":{"values":{"b":{"a":{"type":"#{type}"#{selection}}}}}}})
        submission = Slack::Interaction.from_json(payload).should be_a(Slack::Interactions::ViewSubmission)
        expected = value.empty? ? Slack::Interactions::ValuePresence::Absent : value == "null" ? Slack::Interactions::ValuePresence::Null : Slack::Interactions::ValuePresence::Present
        case action
        when Slack::Interactions::ChannelsSelectAction
          state = submission.state_map.channels_select_value?("b", "a").should_not be_nil
          action.selected_channel_presence.should eq expected
          state.selected_channel_presence.should eq expected
          state.selected_channel.should eq(expected.present? ? "" : nil)
        when Slack::Interactions::MultiChannelsSelectAction
          state = submission.state_map.multi_channels_select_value?("b", "a").should_not be_nil
          action.selected_channels_presence.should eq expected
          state.selected_channels_presence.should eq expected
          state.selected_channels.should eq(expected.present? ? [] of String : nil)
        else
          fail "Expected a typed channel action"
        end
        submission.state_map["b", "missing"]?.should be_nil
        submission.view.should_not(be_nil).state_map["b", "a"]?.should eq submission.state_map["b", "a"]?
      end
    end
  end

  it "reports useful paths for malformed known action and state values" do
    {
      "channels_select" => {
        %({"selected_channel":[]})    => "selected_channel",
        %({"selected_channel":false}) => "selected_channel",
        %({"action_id":42})           => "action_id",
      },
      "multi_channels_select" => {
        %({"selected_channels":{}})          => "selected_channels",
        %({"selected_channels":["C1",null]}) => "selected_channels[1]",
        %({"selected_channels":["C1",42]})   => "selected_channels[1]",
        %({"block_id":[]})                   => "block_id",
        %({"action_ts":false})               => "action_ts",
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
    map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"single":{"type":"channels_select"},"multi":{"type":"multi_channels_select"}}}})))
    expect_raises(Slack::Interactions::TypeMismatch) { map.channels_select_value?("b", "multi") }.path.should eq %(state.values["b"]["multi"])
    expect_raises(Slack::Interactions::TypeMismatch) { map.multi_channels_select_value?("b", "single") }.path.should eq %(state.values["b"]["single"])
  end

  it "does not impose outbound empty or distinct ID policies on received selections" do
    raw = JSON.parse(%({"type":"multi_channels_select","selected_channels":["","future-id","future-id"]}))
    value = Slack::Interactions::MultiChannelsSelectValue.new(raw, "state")
    value.selected_channels.should eq ["", "future-id", "future-id"]
    expect_raises(Slack::Interactions::TypeMismatch) { Slack::Interactions::ChannelsSelectValue.new(raw, "state") }.path.should eq "state.type"
  end
end

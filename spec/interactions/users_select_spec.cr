require "../spec_helper"

describe "received user selections" do
  it "decodes independent actions and full state while preserving unknown data" do
    interaction = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::BlockAction)
      {"type":"block_actions","actions":[
        {"type":"users_select","block_id":"assignment","action_id":"owner","action_ts":"1710000000.000001","selected_user":"U-OWNER","future":false},
        {"type":"multi_users_select","block_id":"assignment","action_id":"reviewers","selected_users":["U-ONE","W-TWO"],"future":[]},
        {"type":"future_select","selected_users":[],"future":{"nested":null}}],
       "state":{"values":{"assignment":{
        "owner":{"type":"users_select","selected_user":"U-OTHER","future":[]},
        "reviewers":{"type":"multi_users_select","selected_users":["U-REVIEWER"],"future":false},
        "unknown":{"type":"future_select","future":{"nested":null}}}}}}
      JSON
    actions = interaction.actions
    single = actions[0].should be_a(Slack::Interactions::UsersSelectAction)
    single.selected_user.should eq "U-OWNER"
    single.action_id.should eq "owner"
    single.block_id.should eq "assignment"
    single.action_ts.should eq "1710000000.000001"
    multi = actions[1].should be_a(Slack::Interactions::MultiUsersSelectAction)
    multi.selected_users.should eq ["U-ONE", "W-TWO"]
    multi.action_ts.should be_nil
    multi.selected_users.should_not(be_nil).clear
    multi.selected_users.should eq ["U-ONE", "W-TWO"]
    unknown = actions[2].should be_a(Slack::Interactions::UnknownAction)
    unknown.raw.should eq JSON.parse(%({"type":"future_select","selected_users":[],"future":{"nested":null}}))
    state = interaction.state
    state.users_select_value?("assignment", "owner").should_not(be_nil).selected_user.should eq "U-OTHER"
    reviewers = state.multi_users_select_value?("assignment", "reviewers").should_not be_nil
    reviewers.selected_users.should eq ["U-REVIEWER"]
    state["assignment", "unknown"]?.should(be_a(Slack::Interactions::UnknownStateValue)).raw.should eq JSON.parse(%({"type":"future_select","future":{"nested":null}}))
  end

  it "distinguishes missing entries, absent fields, null, and empty selections in actions and submissions" do
    {"users_select" => "selected_user", "multi_users_select" => "selected_users"}.each do |type, field|
      {"", "null", type == "users_select" ? %("") : "[]"}.each do |value|
        selection = value.empty? ? "" : %(,"#{field}":#{value})
        action_raw = JSON.parse(%([{"type":"#{type}","block_id":"b","action_id":"a"#{selection}}]))
        action = Slack::Interactions::ActionDecoder.decode(action_raw).first
        payload = %({"type":"view_submission","view":{"state":{"values":{"b":{"a":{"type":"#{type}"#{selection}}}}}}})
        submission = Slack::Interaction.from_json(payload).should be_a(Slack::Interactions::ViewSubmission)
        expected = value.empty? ? Slack::Interactions::ValuePresence::Absent : value == "null" ? Slack::Interactions::ValuePresence::Null : Slack::Interactions::ValuePresence::Present
        case action
        when Slack::Interactions::UsersSelectAction
          state = submission.state.users_select_value?("b", "a").should_not be_nil
          action.selected_user_presence.should eq expected
          state.selected_user_presence.should eq expected
          state.selected_user.should eq(expected.present? ? "" : nil)
        when Slack::Interactions::MultiUsersSelectAction
          state = submission.state.multi_users_select_value?("b", "a").should_not be_nil
          action.selected_users_presence.should eq expected
          state.selected_users_presence.should eq expected
          state.selected_users.should eq(expected.present? ? [] of String : nil)
        else
          fail "Expected a typed user action"
        end
        submission.state["b", "missing"]?.should be_nil
        submission.view.should_not(be_nil).state["b", "a"]?.should eq submission.state["b", "a"]?
      end
    end
  end

  it "reports useful paths for malformed known action and state values" do
    {
      "users_select" => {
        %({"selected_user":[]})    => "selected_user",
        %({"selected_user":false}) => "selected_user",
        %({"action_id":42})        => "action_id",
      },
      "multi_users_select" => {
        %({"selected_users":{}})          => "selected_users",
        %({"selected_users":["U1",null]}) => "selected_users[1]",
        %({"selected_users":["U1",42]})   => "selected_users[1]",
        %({"block_id":[]})                => "block_id",
        %({"action_ts":false})            => "action_ts",
      },
    }.each do |type, cases|
      cases.each do |override, suffix|
        raw = JSON.parse(%({"type":"#{type}","block_id":"b","action_id":"a"})).as_h.merge(JSON.parse(override).as_h)
        interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
        JSON.parse(interaction.to_json)["actions"].should eq JSON.parse([raw].to_json)
        expect_raises(Slack::Interactions::TypeMismatch) { interaction.actions }.path.should eq "actions[0].#{suffix}"
        if suffix.starts_with?("selected_")
          map = Slack::Interactions::StateMap.new(JSON.parse({values: {b: {a: raw}}}.to_json))
          expect_raises(Slack::Interactions::TypeMismatch) { map["b", "a"]? }.path.should eq %(state.values["b"]["a"].#{suffix})
        end
      end
    end
    map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"single":{"type":"users_select"},"multi":{"type":"multi_users_select"}}}})))
    expect_raises(Slack::Interactions::TypeMismatch) { map.users_select_value?("b", "multi") }.path.should eq %(state.values["b"]["multi"])
    expect_raises(Slack::Interactions::TypeMismatch) { map.multi_users_select_value?("b", "single") }.path.should eq %(state.values["b"]["single"])
  end

  it "does not impose outbound empty or distinct ID policies on received selections" do
    raw = JSON.parse(%({"type":"multi_users_select","selected_users":["","future-id","future-id"]}))
    value = Slack::Interactions::MultiUsersSelectValue.new(raw, "state")
    value.selected_users.should eq ["", "future-id", "future-id"]
    expect_raises(Slack::Interactions::TypeMismatch) { Slack::Interactions::UsersSelectValue.new(raw, "state") }.path.should eq "state.type"
  end
end

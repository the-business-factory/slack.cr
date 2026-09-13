require "../spec_helper"

private def received_submission(view_fields : String) : Slack::Interactions::ViewSubmission
  interaction = Slack::Interaction.from_json(%({"type":"view_submission","team":null,"view":{#{view_fields}}}))
  interaction.should be_a(Slack::Interactions::ViewSubmission)
  case interaction
  when Slack::Interactions::ViewSubmission then interaction
  else                                          fail("Expected view submission")
  end
end

private def received_block_action(fields : String = "") : Slack::Interactions::BlockAction
  interaction = Slack::Interaction.from_json(%({"type":"block_actions"#{fields}}))
  case interaction
  when Slack::Interactions::BlockAction then interaction
  else                                       fail("Expected block action")
  end
end

describe "Typed Block Kit interaction access" do
  it "checks discriminators when callers construct typed inbound values directly" do
    raw = JSON.parse(%({"type":"future_control","block_id":"b","action_id":"a","value":"text"}))
    expect_raises(Slack::Interactions::TypeMismatch, "action.type: expected button, got future_control") do
      Slack::Interactions::ButtonAction.new(raw)
    end
    expect_raises(Slack::Interactions::TypeMismatch, "entry.type: expected plain_text_input, got future_control") do
      Slack::Interactions::PlainTextValue.new(raw, "entry")
    end
  end

  it "decodes buttons without outbound text and preserves new action types" do
    interaction = received_block_action(%(,"actions":[{"type":"button","block_id":"request","action_id":"open","value":"42","action_ts":"1710000000.000001","future":true},{"type":"future_control","data":{"selected":[]}}]))
    interaction.channel.should be_nil
    interaction.state.should be_nil
    actions = interaction.decoded_actions
    case action = actions.first
    when Slack::Interactions::ButtonAction
      action.action_id.should eq "open"
      action.block_id.should eq "request"
      action.value.should eq "42"
      action.action_ts.should eq "1710000000.000001"
      action.raw["future"].as_bool.should be_true
    else
      fail("Expected typed button")
    end
    case unknown = actions.last
    when Slack::Interactions::UnknownAction
      unknown.type.should eq "future_control"
      unknown.raw.should eq JSON.parse(%({"type":"future_control","data":{"selected":[]}}))
    else
      fail("Expected unknown action")
    end
    interaction.actions.try(&.as_a.size).should eq 2
  end

  {"" => Slack::Interactions::ValuePresence::Absent, %(,"value":null) => Slack::Interactions::ValuePresence::Null, %(,"value":"") => Slack::Interactions::ValuePresence::Present}.each do |field, presence|
    it "retains button value #{presence}" do
      action = received_block_action(%(,"actions":[{"type":"button","block_id":"b","action_id":"a"#{field}}])).decoded_actions.first
      case action
      when Slack::Interactions::ButtonAction
        action.value_presence.should eq presence
        action.value.should eq(presence.present? ? "" : nil)
      else
        fail("Expected button")
      end
    end
  end

  {"" => Slack::Interactions::ValuePresence::Absent, "null" => Slack::Interactions::ValuePresence::Null, "{}" => Slack::Interactions::ValuePresence::Present}.each do |state, presence|
    it "distinguishes #{presence} state in block actions and view submissions" do
      field = state.empty? ? "" : %("state":#{state})
      action = received_block_action(field.empty? ? "" : ",#{field}")
      submission = received_submission(field)
      {action.state_map, submission.state_map}.each do |map|
        map.presence.should eq presence
        map.values_presence.should eq Slack::Interactions::ValuePresence::Absent
        map.plain_text?("missing", "missing").should be_nil
      end
    end
  end

  {"null" => Slack::Interactions::ValuePresence::Null, "{}" => Slack::Interactions::ValuePresence::Present}.each do |values, presence|
    it "distinguishes #{presence} state.values" do
      submission = received_submission(%("state":{"values":#{values}}))
      submission.state_map.values_presence.should eq presence
      submission.plain_text?("missing", "missing").should be_nil
    end
  end

  it "distinguishes an absent entry from absent, null, and empty plain text values" do
    submission = received_submission(%("state":{"values":{"b":{"absent":{"type":"plain_text_input"},"null":{"type":"plain_text_input","value":null},"empty":{"type":"plain_text_input","value":""},"text":{"type":"plain_text_input","value":"Line 1\\n界"}}}}))
    map = submission.state_map
    map["b", "missing"]?.should be_nil
    map.plain_text_value?("b", "absent").try(&.value_presence).should eq Slack::Interactions::ValuePresence::Absent
    map.plain_text_value?("b", "null").try(&.value_presence).should eq Slack::Interactions::ValuePresence::Null
    map.plain_text_value?("b", "empty").try(&.value_presence).should eq Slack::Interactions::ValuePresence::Present
    submission.plain_text?("b", "null").should be_nil
    submission.plain_text?("b", "empty").should eq ""
    submission.plain_text?("b", "text").should eq "Line 1\n界"
  end

  it "retains unknown state types and empty selections, with useful mismatch errors" do
    submission = received_submission(%("state":{"values":{"b":{"a":{"type":"future_select","selected_options":[],"extra":true}}}}))
    case entry = submission.state_map["b", "a"]?
    when Slack::Interactions::UnknownStateValue
      entry.type.should eq "future_select"
      entry.raw.should eq JSON.parse(%({"type":"future_select","selected_options":[],"extra":true}))
    else
      fail("Expected unknown state value")
    end
    error = expect_raises(Slack::Interactions::TypeMismatch) { submission.plain_text?("b", "a") }
    error.path.should eq %(view.state.values["b"]["a"])
    error.expected.should eq "plain_text_input"
    error.actual.should eq "future_select"
    error.message.to_s.should contain("future_select")
  end

  it "keeps null unknown state entries accessible" do
    submission = received_submission(%("state":{"values":{"b":{"a":null}}}))
    case entry = submission.state_map["b", "a"]?
    when Slack::Interactions::UnknownStateValue
      entry.raw.raw.should be_nil
    else
      fail("Expected a retained null entry")
    end
  end

  it "allows source-dependent fields for message, Home, modal, and org interactions" do
    [
      %(,"container":{"type":"message"},"channel":{"id":"C123"}),
      %(,"container":{"type":"view"},"view":{"type":"home"}),
      %(,"team":null,"container":{"type":"view"},"view":{"type":"modal","state":null}),
    ].each do |fields|
      action = received_block_action(fields)
      action.decoded_actions.should be_empty
      action.state_map.plain_text?("b", "a").should be_nil
    end
    [%("type":"view_submission"), %("type":"view_submission","view":null,"response_urls":null), %("type":"view_closed","view":{"state":{}})].each do |fields|
      Slack::Interaction.from_json("{#{fields}}")
    end
    submission = received_submission("")
    submission.response_urls.should be_nil
    submission.team.should be_nil
  end

  it "reports malformed known values and container shapes at their field paths" do
    {
      %({"values":{"b":{"a":{"type":"plain_text_input","value":42}}}}) => %(view.state.values["b"]["a"].value),
      %({"values":[]})                                                 => "view.state.values",
      %({"values":{"b":[]}})                                           => %(view.state.values["b"]),
      %([])                                                            => "view.state",
    }.each do |state, path|
      submission = received_submission(%("state":#{state}))
      error = expect_raises(Slack::Interactions::TypeMismatch) { submission.plain_text?("b", "a") }
      error.path.should eq path
    end
    error = expect_raises(Slack::Interactions::TypeMismatch) do
      received_block_action(%(,"actions":[{"type":"button","block_id":"b","action_id":42}])).decoded_actions
    end
    error.path.should eq "actions[0].action_id"
    expect_raises(Slack::Interactions::TypeMismatch, "actions: expected array") { received_block_action(%(,"actions":{})).decoded_actions }
  end

  it "preserves unknown actions and state through the signed public HTTP entrypoint" do
    body = URI::Params.encode({"payload" => %({"type":"block_actions","team":null,"actions":[{"type":"future_action","extra":[]}],"state":{"values":{"b":{"a":{"type":"future_value","selected_ids":[]}}}}})})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }
    interaction = Slack.process_interaction(HTTP::Request.new("POST", "/interactions", headers, body))
    case interaction
    when Slack::Interactions::BlockAction
      interaction.decoded_actions.first.should be_a Slack::Interactions::UnknownAction
      interaction.state_map["b", "a"]?.should be_a Slack::Interactions::UnknownStateValue
      expect_raises(Slack::Interactions::TypeMismatch, "future_value") { interaction.state_map.plain_text?("b", "a") }
    else
      fail("Expected block action")
    end
  end
end

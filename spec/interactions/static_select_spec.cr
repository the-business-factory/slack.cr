require "../spec_helper"

private def select_interaction(payload : String, signed : Bool) : Slack::Interaction
  return Slack::Interaction.from_json(payload) unless signed
  body = URI::Params.encode({"payload" => payload})
  timestamp = Time.utc.to_unix.to_s
  headers = HTTP::Headers{
    "X-Slack-Request-Timestamp" => timestamp,
    "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
  }
  Slack.process_interaction(HTTP::Request.new("POST", "/interactions", headers, body))
end

private def selection_state(entry : String) : Slack::Interactions::StateMap
  interaction = Slack::Interaction.from_json(%({"type":"view_submission","view":{"state":{"values":{"b":{"a":#{entry}}}}}}))
  case interaction
  when Slack::Interactions::ViewSubmission then interaction.state_map
  else                                          fail("Expected submission")
  end
end

describe "Typed static selection interactions" do
  {false, true}.each do |signed|
    {"message_action", "modal_action", "home_action", "submission"}.each do |fixture|
      it "reads #{fixture} through #{signed ? "signed HTTP" : "JSON"} public entrypoints" do
        interaction = select_interaction(File.read("spec/fixtures/block_kit/phase_5_#{fixture}.json"), signed)
        case interaction
        when Slack::Interactions::BlockAction, Slack::Interactions::ViewSubmission
          map = interaction.state_map
          single = map.static_select_value?("preferences", "color") || fail("Missing single state")
          single.selected_option_presence.should eq Slack::Interactions::ValuePresence::Present
          single.raw["future_state"].as_bool.should be_true
          option = single.selected_option || fail("Missing option")
          option.value.should eq "red"
          option.text.should eq "Red"
          option.text_type.should eq "plain_text"
          option.raw["future_option"].as_a.size.should eq 2
          option.raw["text"]["future_text"].as_s.should eq "kept"
          multi = map.multi_static_select_value?("preferences", "colors") || fail("Missing multi state")
          multi.selected_options.try(&.map(&.value)).should eq ["red"]
          multi.selected_options.try(&.clear)
          multi.selected_options.try(&.size).should eq 1
          map.static_select_value?("preferences", "missing").should be_nil
          map.multi_static_select_value?("preferences", "missing").should be_nil
          map.static_select_value?("preferences", "single_absent").try(&.selected_option_presence).should eq Slack::Interactions::ValuePresence::Absent
          map.static_select_value?("preferences", "single_null").try(&.selected_option_presence).should eq Slack::Interactions::ValuePresence::Null
          map.multi_static_select_value?("preferences", "multi_absent").try(&.selected_options_presence).should eq Slack::Interactions::ValuePresence::Absent
          map.multi_static_select_value?("preferences", "multi_null").try(&.selected_options_presence).should eq Slack::Interactions::ValuePresence::Null
          empty = map.multi_static_select_value?("preferences", "multi_empty") || fail("Missing cleared state")
          empty.selected_options_presence.should eq Slack::Interactions::ValuePresence::Present
          empty.selected_options.should eq [] of Slack::Interactions::SelectedOption
          case unknown = map["preferences", "future"]?
          when Slack::Interactions::UnknownStateValue
            unknown.raw.should eq JSON.parse(%({"type":"future_select","selected_options":[],"extra":null}))
          else
            fail("Expected unknown state")
          end
          expect_raises(Slack::Interactions::TypeMismatch) { map.static_select_value?("preferences", "colors") }
          expect_raises(Slack::Interactions::TypeMismatch) { map.multi_static_select_value?("preferences", "color") }
          expect_raises(Slack::Interactions::TypeMismatch) { map.plain_text_value?("preferences", "color") }
          if interaction.is_a?(Slack::Interactions::BlockAction)
            case action = interaction.decoded_actions.first
            when Slack::Interactions::StaticSelectAction
              action.action_id.should eq "color"
              action.block_id.should eq "preferences"
              action.action_ts.should eq "1710000000.000001"
              action.selected_option.try(&.value).should eq "red"
              action.raw["future_action"].as_bool.should be_true
            else
              fail("Expected static action")
            end
            case action = interaction.decoded_actions[1]
            when Slack::Interactions::MultiStaticSelectAction
              action.action_id.should eq "colors"
              action.block_id.should eq "preferences"
              action.action_ts.should eq "1710000000.000002"
              action.selected_options.try(&.map(&.value)).should eq ["red"]
            else
              fail("Expected multi static action")
            end
            case unknown = interaction.decoded_actions.last
            when Slack::Interactions::UnknownAction
              unknown.raw.should eq JSON.parse(%({"type":"future_select","selected_options":[],"extra":null}))
            else
              fail("Expected unknown action")
            end
            if fixture != "message_action"
              interaction.channel.should be_nil
              interaction.view.try(&.state_map.static_select_value?("preferences", "color").try(&.selected_option.try(&.value))).should eq "red"
            end
          end
        else
          fail("Expected action or submission")
        end
      end
    end
  end

  it "preserves absent, null, and cleared action selections" do
    {"" => Slack::Interactions::ValuePresence::Absent, "null" => Slack::Interactions::ValuePresence::Null, "[]" => Slack::Interactions::ValuePresence::Present}.each do |value, presence|
      field = value.empty? ? "" : %(,"selected_options":#{value})
      interaction = select_interaction(%({"type":"block_actions","actions":[{"type":"multi_static_select","block_id":"b","action_id":"a"#{field}}]}), false)
      case interaction
      when Slack::Interactions::BlockAction
        case action = interaction.decoded_actions.first
        when Slack::Interactions::MultiStaticSelectAction
          action.selected_options_presence.should eq presence
          action.selected_options.should eq(presence.present? ? [] of Slack::Interactions::SelectedOption : nil)
        else
          fail("Expected multi action")
        end
      else
        fail("Expected block action")
      end
      next if presence.present?
      field = value.empty? ? "" : %(,"selected_option":#{value})
      interaction = select_interaction(%({"type":"block_actions","actions":[{"type":"static_select","block_id":"b","action_id":"a"#{field}}]}), true)
      case interaction
      when Slack::Interactions::BlockAction
        case action = interaction.decoded_actions.first
        when Slack::Interactions::StaticSelectAction
          action.selected_option_presence.should eq presence
          action.selected_option.should be_nil
        else
          fail("Expected static action")
        end
      else
        fail("Expected block action")
      end
    end
  end

  it "does not apply outbound lengths, membership, or text discriminators to received options" do
    option = {text: {type: "future_text", text: "界" * 76}, value: ""}.to_json
    map = selection_state(%({"type":"static_select","selected_option":#{option}}))
    selected = map.static_select_value?("b", "a").try(&.selected_option) || fail("Missing option")
    selected.text_type.should eq "future_text"
    selected.text.size.should eq 76
    selected.value.should eq ""
    selected.raw.should eq JSON.parse(option)
  end

  it "reports malformed known selections at nested field paths while raw payloads remain accessible" do
    {
      %({"type":"static_select","selected_option":[]})                               => "selected_option",
      %({"type":"static_select","selected_option":{}})                               => "selected_option.value",
      %({"type":"static_select","selected_option":{"value":42}})                     => "selected_option.value",
      %({"type":"static_select","selected_option":{"value":"x","text":null}})        => "selected_option.text",
      %({"type":"multi_static_select","selected_options":{}})                        => "selected_options",
      %({"type":"multi_static_select","selected_options":[null]})                    => "selected_options[0]",
      %({"type":"multi_static_select","selected_options":[{"value":"x","text":{}}]}) => "selected_options[0].text.text",
    }.each do |entry, suffix|
      map = selection_state(entry)
      map.raw.should_not be_nil
      error = expect_raises(Slack::Interactions::TypeMismatch) { map["b", "a"]? }
      error.path.should eq %(view.state.values["b"]["a"].#{suffix})
      interaction = select_interaction(%({"type":"block_actions","actions":[#{entry}]}), false)
      case interaction
      when Slack::Interactions::BlockAction
        interaction.actions.try(&.as_a.first).should eq JSON.parse(entry)
        error = expect_raises(Slack::Interactions::TypeMismatch) { interaction.decoded_actions }
        error.path.should eq "actions[0].#{suffix}"
      else
        fail("Expected action")
      end
    end
  end

  it "checks action IDs and direct decoder discriminators" do
    interaction = select_interaction(%({"type":"block_actions","actions":[{"type":"static_select","block_id":"b","action_id":42}]}), false)
    case interaction
    when Slack::Interactions::BlockAction
      expect_raises(Slack::Interactions::TypeMismatch) { interaction.decoded_actions }.path.should eq "actions[0].action_id"
    else
      fail("Expected action")
    end
    raw = JSON.parse(%({"type":"future_select"}))
    expect_raises(Slack::Interactions::TypeMismatch) { Slack::Interactions::StaticSelectValue.new(raw, "entry") }.path.should eq "entry.type"
    expect_raises(Slack::Interactions::TypeMismatch) { Slack::Interactions::MultiStaticSelectValue.new(raw, "entry") }.path.should eq "entry.type"
  end
end

require "../spec_helper"

module RichTextInputInteractionSpec
  alias Received = Slack::Interactions::RichText

  describe "received rich text inputs" do
    it "decodes an independently authored dispatched action and view state as rich text trees" do
      interaction = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::BlockAction)
        {"type":"block_actions","container":{"type":"view","view_id":"V-SYNTHETIC"},"actions":[
         {"type":"rich_text_input","block_id":"standup","action_id":"summary","action_ts":"1710000000.000001","future":true,
          "rich_text_value":{"type":"rich_text","elements":[{"type":"rich_text_section","elements":[
           {"type":"text","text":"Pairing with "},{"type":"user","user_id":"U-PAIR"}]}]}}],
         "view":{"type":"home","state":{"values":{"standup":{"summary":{"type":"rich_text_input","rich_text_value":{"type":"rich_text","elements":[
          {"type":"rich_text_list","style":"bullet","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"Ship","style":{"bold":true}}]}]},
          {"type":"rich_text_future","elements":[]}]}}}}}}}
        JSON
      action = interaction.decoded_actions.first.should be_a(Slack::Interactions::RichTextInputAction)
      action.type.should eq "rich_text_input"
      action.block_id.should eq "standup"
      action.action_id.should eq "summary"
      action.action_ts.should eq "1710000000.000001"
      action.raw["future"].as_bool.should be_true
      action.value_presence.present?.should be_true
      section = action.rich_text_value.should_not(be_nil).elements.first.should be_a(Received::Section)
      section.elements.map(&.class).should eq [Received::Text, Received::User]
      section.elements.last.should(be_a(Received::User)).user_id.should eq "U-PAIR"

      value = interaction.view.should_not(be_nil).state_map.rich_text_input_value?("standup", "summary").should_not be_nil
      value.type.should eq "rich_text_input"
      tree = value.rich_text_value.should_not be_nil
      list = tree.elements.first.should be_a(Received::List)
      list.elements.first.elements.first.should(be_a(Received::Text)).style.should_not(be_nil).bold.should be_true
      tree.elements.last.should(be_a(Received::Unknown)).type.should eq "rich_text_future"
    end

    it "distinguishes absent and null values and rejects the wrong state family" do
      {"" => Slack::Interactions::ValuePresence::Absent, %(,"rich_text_value":null) => Slack::Interactions::ValuePresence::Null}.each do |field, presence|
        payload = %({"type":"view_submission","view":{"state":{"values":{"standup":{"summary":{"type":"rich_text_input"#{field}},"note":{"type":"plain_text_input","value":"x"}}}}}})
        state = Slack::Interaction.from_json(payload).should(be_a(Slack::Interactions::ViewSubmission)).state_map
        value = state.rich_text_input_value?("standup", "summary").should_not be_nil
        value.value_presence.should eq presence
        value.rich_text_value.should be_nil
        action = Slack::Interactions::ActionDecoder.decode(JSON.parse(%([{"type":"rich_text_input","block_id":"b","action_id":"a"#{field}}]))).first
        action.should(be_a(Slack::Interactions::RichTextInputAction)).value_presence.should eq presence
        state.rich_text_input_value?("standup", "missing").should be_nil
        expect_raises(Slack::Interactions::TypeMismatch) { state.rich_text_input_value?("standup", "note") }.path.should eq %(view.state.values["standup"]["note"])
      end
    end

    it "rejects malformed trees and wrong JSON types with paths while keeping the raw payload available" do
      {
        %("rich text")                                                                                 => "actions[0].rich_text_value",
        %({"type":"rich_text_section","elements":[]})                                                  => "actions[0].rich_text_value.type",
        %({"type":"rich_text","elements":[{"type":"text","text":"loose"}]})                            => "actions[0].rich_text_value.elements[0].type",
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"user"}]}]}) => "actions[0].rich_text_value.elements[0].elements[0].user_id",
      }.each do |tree, path|
        raw = %({"type":"rich_text_input","block_id":"b","action_id":"a","rich_text_value":#{tree}})
        interaction = Slack::Interaction.from_json(%({"type":"block_actions","actions":[#{raw}]})).should be_a(Slack::Interactions::BlockAction)
        interaction.actions.should eq JSON.parse("[#{raw}]")
        expect_raises(Slack::Interactions::TypeMismatch) { interaction.decoded_actions }.path.should eq path
      end
      {"action_id" => "false", "block_id" => "[]", "action_ts" => "1"}.each do |field, value|
        raw = JSON.parse(%({"type":"rich_text_input","block_id":"b","action_id":"a"})).as_h
        raw[field] = JSON.parse(value)
        expect_raises(Slack::Interactions::TypeMismatch) { Slack::Interactions::ActionDecoder.decode(JSON.parse([raw].to_json)) }.path.should eq "actions[0].#{field}"
      end
      map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"a":{"type":"rich_text_input","rich_text_value":[]}}}})))
      expect_raises(Slack::Interactions::TypeMismatch) { map["b", "a"]? }.path.should eq %(state.values["b"]["a"].rich_text_value)
    end
  end
end

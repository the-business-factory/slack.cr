require "../../spec_helper"

module NumberInputSpec
  alias UI = Slack::UI::Checked
  alias NumberInput = UI::BlockElements::NumberInput

  describe NumberInput do
    it "serializes the independent number contract with string-typed numbers" do
      config = UI::CompositionObjects::DispatchActionConfig.new([UI::CompositionObjects::DispatchTrigger::OnEnterPressed])
      input = NumberInput.new(is_decimal_allowed: true, action_id: "rate", initial_value: "0.25",
        min_value: "-10", max_value: "5.5", dispatch_action_config: config,
        focus_on_load: false, placeholder: UI.plain("Rate", emoji: false))
      JSON.parse(input.to_json).should eq JSON.parse(<<-JSON)
        {"type":"number_input","is_decimal_allowed":true,"action_id":"rate","initial_value":"0.25",
         "min_value":"-10","max_value":"5.5","dispatch_action_config":{"trigger_actions_on":["on_enter_pressed"]},
         "focus_on_load":false,"placeholder":{"type":"plain_text","text":"Rate","emoji":false}}
        JSON
      JSON.parse(NumberInput.new(is_decimal_allowed: false).to_json).should eq JSON.parse(%({"type":"number_input","is_decimal_allowed":false}))
    end

    it "rejects an inverted range with exact decimal comparison" do
      {
        {"1", "1"}, {"-2", "-1"}, {"0.1", "0.10000000000000001"}, {"-0", "0"}, {"9", "10"}, {"007", "8"},
      }.each do |minimum, maximum|
        NumberInput.new(is_decimal_allowed: true, min_value: minimum, max_value: maximum).validate.should be_empty
      end
      {
        {"2", "1"}, {"-1", "-2"}, {"0.10000000000000001", "0.1"}, {"10", "9"}, {"1.5", "1.25"}, {"0", "-0.5"},
      }.each do |minimum, maximum|
        error = expect_raises(UI::ValidationError) { NumberInput.new(is_decimal_allowed: true, min_value: minimum, max_value: maximum) }
        error.issues.map(&.code).should eq ["number_input.range.inverted"]
        error.issues.first.path.should eq "min_value"
      end
    end

    it "requires plain decimal numbers and whole numbers when decimals are not allowed" do
      {"initial_value", "min_value", "max_value"}.each do |field|
        {"", "1e3", "+5", ".5", "5.", "1,000", " 5", "5\n", "NaN", "--1"}.each do |value|
          error = expect_raises(UI::ValidationError) { number_with(field, value, decimals: true) }
          error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"number_input.#{field}.invalid", field}]
        end
        {"-10", "0", "42"}.each { |value| number_with(field, value, decimals: false).validate.should be_empty }
        {"0.25", "-10.0"}.each do |value|
          number_with(field, value, decimals: true).validate.should be_empty
          error = expect_raises(UI::ValidationError) { number_with(field, value, decimals: false) }
          error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"number_input.#{field}.decimal_not_allowed", field}]
        end
      end
    end

    it "checks action ID and placeholder limits" do
      NumberInput.new(is_decimal_allowed: false, action_id: "界" * 255, placeholder: UI.plain("界" * 150)).validate.should be_empty
      expect_raises(UI::ValidationError) { NumberInput.new(is_decimal_allowed: false, action_id: "界" * 256) }.issues.first.path.should eq "action_id"
      expect_raises(UI::ValidationError) { NumberInput.new(is_decimal_allowed: false, placeholder: UI.plain("界" * 151)) }.issues.first.path.should eq "placeholder.text"
    end
  end

  describe UI::Blocks::ModalInput do
    it "places a number input in a form modal as an Input block" do
      number = NumberInput.new(is_decimal_allowed: false, action_id: "seats", min_value: "1", max_value: "50", focus_on_load: true)
      view = UI.form_modal(title: UI.plain("Seats"), submit: UI.plain("Save")) do |builder|
        builder.input(label: UI.plain("Seats"), element: number, block_id: "seats", hint: UI.plain("Whole seats"),
          optional: false, dispatch_action: false)
        builder.input(label: UI.plain("Note"), element: UI::BlockElements::PlainTextInput.new(action_id: "note"))
      end
      JSON.parse(view.to_json).should eq JSON.parse(<<-JSON)
        {"type":"modal","title":{"type":"plain_text","text":"Seats"},"submit":{"type":"plain_text","text":"Save"},"blocks":[
         {"type":"input","label":{"type":"plain_text","text":"Seats"},"block_id":"seats","hint":{"type":"plain_text","text":"Whole seats"},
          "optional":false,"dispatch_action":false,
          "element":{"type":"number_input","is_decimal_allowed":false,"action_id":"seats","min_value":"1","max_value":"50","focus_on_load":true}},
         {"type":"input","label":{"type":"plain_text","text":"Note"},"element":{"type":"plain_text_input","action_id":"note"}}]}
        JSON
    end

    it "applies Input limits, nested element paths, and view-wide focus" do
      number = NumberInput.new(is_decimal_allowed: false, focus_on_load: true)
      expect_raises(UI::ValidationError) { UI::Blocks::ModalInput.new(label: UI.plain("界" * 2001), element: number) }.issues.first.path.should eq "label.text"
      expect_raises(UI::ValidationError) { UI::Blocks::ModalInput.new(label: UI.plain("Seats"), element: number, block_id: "b" * 256) }.issues.first.path.should eq "block_id"
      input = UI::Blocks::ModalInput.new(label: UI.plain("Seats"), element: number, block_id: "seats")
      error = expect_raises(UI::ValidationError) do
        UI::FormModal.new(title: UI.plain("Seats"), submit: UI.plain("Save"), blocks: [
          input,
          UI::Blocks::Input.new(label: UI.plain("Note"), element: UI::BlockElements::PlainTextInput.new(focus_on_load: true), block_id: "seats"),
        ] of UI::ModalBlock)
      end
      error.issues.map(&.path).should eq ["blocks[1].block_id", "blocks[1].element.focus_on_load"]
    end
  end

  def self.number_with(field : String, value : String, *, decimals : Bool) : NumberInput
    case field
    when "initial_value" then NumberInput.new(is_decimal_allowed: decimals, initial_value: value)
    when "min_value"     then NumberInput.new(is_decimal_allowed: decimals, min_value: value)
    else                      NumberInput.new(is_decimal_allowed: decimals, max_value: value)
    end
  end
end

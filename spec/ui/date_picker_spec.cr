require "../spec_helper"

module DatePickerSpec
  alias UI = Slack::UI
  alias Picker = UI::BlockElements::DatePicker

  describe Picker do
    it "serializes the independent date contract and omits unset fields" do
      confirm = UI::CompositionObjects::Confirmation.new(title: UI.plain("Date?"),
        text: UI.plain("Use this date"), confirm: UI.plain("Yes"), deny: UI.plain("No"))
      picker = Picker.new(action_id: "date", initial_date: "2028-02-29",
        placeholder: UI.plain("Choose date", emoji: false), confirm: confirm, focus_on_load: false)
      JSON.parse(picker.to_json).should eq JSON.parse(<<-JSON)
        {"type":"datepicker","action_id":"date","initial_date":"2028-02-29",
         "placeholder":{"type":"plain_text","text":"Choose date","emoji":false},"focus_on_load":false,
         "confirm":{"title":{"type":"plain_text","text":"Date?"},"text":{"type":"plain_text","text":"Use this date"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
      JSON.parse(Picker.new.to_json).should eq JSON.parse(%({"type":"datepicker"}))
    end

    it "checks exact calendar dates including leap years without a scheduling window" do
      {"0001-01-01", "9999-12-31", "2000-02-29", "2028-02-29", "2026-04-30"}.each do |date|
        Picker.new(initial_date: date).validate.should be_empty
      end
      {"", "2026-2-01", "2026-02-29", "1900-02-29", "2026-04-31", "2026-00-01", "2026-13-01", "2026-01-00", "0000-01-01", "2026-01-01\n"}.each do |date|
        error = expect_raises(UI::ValidationError) { Picker.new(initial_date: date) }
        error.issues.first.path.should eq "initial_date"
        error.issues.first.code.should eq "datepicker.initial_date.invalid"
      end
      Picker.new(action_id: "界" * 255, placeholder: UI.plain("界" * 150)).validate.should be_empty
      expect_raises(UI::ValidationError) { Picker.new(action_id: "界" * 256) }.issues.first.path.should eq "action_id"
      expect_raises(UI::ValidationError) { Picker.new(placeholder: UI.plain("界" * 151)) }.issues.first.path.should eq "placeholder.text"
    end
  end
end

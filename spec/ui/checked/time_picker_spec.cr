require "../../spec_helper"

module TimePickerSpec
  alias UI = Slack::UI::Checked
  alias Picker = UI::BlockElements::TimePicker

  describe Picker do
    it "serializes the independent time contract including the timezone hint" do
      confirm = UI::CompositionObjects::Confirmation.new(title: UI.plain("Time?"),
        text: UI.plain("Use this time"), confirm: UI.plain("Yes"), deny: UI.plain("No"))
      picker = Picker.new(action_id: "time", initial_time: "23:59", timezone: "America/Chicago",
        placeholder: UI.plain("Choose time", emoji: false), confirm: confirm, focus_on_load: true)
      JSON.parse(picker.to_json).should eq JSON.parse(<<-JSON)
        {"type":"timepicker","action_id":"time","initial_time":"23:59","timezone":"America/Chicago",
         "placeholder":{"type":"plain_text","text":"Choose time","emoji":false},"focus_on_load":true,
         "confirm":{"title":{"type":"plain_text","text":"Time?"},"text":{"type":"plain_text","text":"Use this time"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
      JSON.parse(Picker.new.to_json).should eq JSON.parse(%({"type":"timepicker"}))
      JSON.parse(Picker.new(focus_on_load: false).to_json).should eq JSON.parse(%({"type":"timepicker","focus_on_load":false}))
    end

    it "checks a precise 24-hour clock without parsing an instant" do
      {"00:00", "12:30", "23:59"}.each { |time| Picker.new(initial_time: time).validate.should be_empty }
      {"", "1:30", "24:00", "12:60", "12:30:00", "12:30\n"}.each do |time|
        error = expect_raises(UI::ValidationError) { Picker.new(initial_time: time) }
        error.issues.first.path.should eq "initial_time"
        error.issues.first.code.should eq "timepicker.initial_time.invalid"
      end
      Picker.new(action_id: "界" * 255, placeholder: UI.plain("界" * 150)).validate.should be_empty
      expect_raises(UI::ValidationError) { Picker.new(action_id: "界" * 256) }.issues.first.path.should eq "action_id"
      expect_raises(UI::ValidationError) { Picker.new(placeholder: UI.plain("界" * 151)) }.issues.first.path.should eq "placeholder.text"
    end
  end
end

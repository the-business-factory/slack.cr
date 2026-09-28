require "../spec_helper"

module DatetimePickerSpec
  alias UI = Slack::UI
  alias Picker = UI::BlockElements::DatetimePicker

  describe Picker do
    it "serializes the independent datetime contract with Unix seconds" do
      confirm = UI::CompositionObjects::Confirmation.new(title: UI.plain("Start?"),
        text: UI.plain("Use this start"), confirm: UI.plain("Yes"), deny: UI.plain("No"))
      start = Time.local(2021, 8, 10, 15, 17, location: Time::Location.fixed(-7 * 3600))
      picker = Picker.new(action_id: "start", initial_date_time: start, confirm: confirm, focus_on_load: true)
      JSON.parse(picker.to_json).should eq JSON.parse(<<-JSON)
        {"type":"datetimepicker","action_id":"start","initial_date_time":1628633820,"focus_on_load":true,
         "confirm":{"title":{"type":"plain_text","text":"Start?"},"text":{"type":"plain_text","text":"Use this start"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
      picker.initial_date_time.should eq start
      JSON.parse(Picker.new.to_json).should eq JSON.parse(%({"type":"datetimepicker"}))
      JSON.parse(Picker.new(focus_on_load: false).to_json).should eq JSON.parse(%({"type":"datetimepicker","focus_on_load":false}))
    end

    it "sends whole seconds and requires a ten-digit Unix timestamp" do
      JSON.parse(Picker.new(initial_date_time: Time.unix_ms(1_628_633_820_999)).to_json)["initial_date_time"].should eq 1628633820
      {1_000_000_000_i64, 9_999_999_999_i64}.each { |seconds| Picker.new(initial_date_time: Time.unix(seconds)).validate.should be_empty }
      {Time.unix(999_999_999), Time.unix(10_000_000_000), Time.unix(-1)}.each do |time|
        error = expect_raises(UI::ValidationError) { Picker.new(initial_date_time: time) }
        error.issues.first.path.should eq "initial_date_time"
        error.issues.first.code.should eq "datetimepicker.initial_date_time.invalid"
      end
      Picker.new(action_id: "界" * 255).validate.should be_empty
      expect_raises(UI::ValidationError) { Picker.new(action_id: "界" * 256) }.issues.first.path.should eq "action_id"
    end

    it "composes in Actions and Input on messages and modals, and is rejected on Home" do
      picker = Picker.new(action_id: "start", focus_on_load: true)
      {UI::MessageBuilder.new(fallback_text: "Schedule"),
       UI::FormModalBuilder.new(title: UI.plain("Schedule"), submit: UI.plain("Save"))}.each do |builder|
        builder.actions({picker})
        builder.input(label: UI.plain("End"), element: Picker.new(action_id: "end"))
        wire = JSON.parse(builder.build.to_json)
        wire["blocks"][0]["elements"][0]["type"].should eq "datetimepicker"
        wire["blocks"][1]["element"]["type"].should eq "datetimepicker"
      end
      display = UI::DisplayModalBuilder.new(title: UI.plain("Schedule"))
      display.actions({picker})
      display.build.validate.should be_empty
      display.section(UI.plain("Pick"), accessory: UI::BlockElements::DatePicker.new(focus_on_load: true))
      expect_raises(UI::ValidationError) { display.build }.issues.first.path.should eq "blocks[1].accessory.focus_on_load"

      home = UI::HomeBuilder.new
      home.actions({UI::BlockElements::Button.new(text: UI.plain("Go"), action_id: "go"), Picker.new})
      home.input(label: UI.plain("End"), element: Picker.new)
      issues = expect_raises(UI::ValidationError) { home.build }.issues
      issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"home.datetimepicker.unsupported_surface", "blocks[0].elements[1]"},
        {"home.datetimepicker.unsupported_surface", "blocks[1].element"},
      ]
    end
  end
end

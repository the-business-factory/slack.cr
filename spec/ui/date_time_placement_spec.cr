require "../../spec_helper"

module DateTimePlacementSpec
  alias UI = Slack::UI::Checked

  it "composes both pickers across supported slots and surfaces" do
    date = UI::BlockElements::DatePicker.new(action_id: "date", focus_on_load: true)
    time = UI::BlockElements::TimePicker.new(action_id: "time", focus_on_load: false)
    {UI::MessageBuilder.new(fallback_text: "Schedule"), UI::HomeBuilder.new,
     UI::FormModalBuilder.new(title: UI.plain("Schedule"), submit: UI.plain("Save"))}.each do |builder|
      builder.section(UI.plain("Date"), accessory: date)
      builder.actions({time})
      builder.input(label: UI.plain("Date"), element: UI::BlockElements::DatePicker.new)
      builder.input(label: UI.plain("Time"), element: time)
      wire = JSON.parse(builder.build.to_json)
      wire["blocks"][0]["accessory"]["type"].should eq "datepicker"
      wire["blocks"][1]["elements"][0]["type"].should eq "timepicker"
      wire["blocks"][2]["element"]["type"].should eq "datepicker"
      wire["blocks"][3]["element"]["type"].should eq "timepicker"
    end
    display = UI::DisplayModalBuilder.new(title: UI.plain("Schedule"))
    display.section(UI.plain("Date"), accessory: date)
    display.actions({time})
    display.build.validate.should be_empty
    display.actions({UI::BlockElements::TimePicker.new(focus_on_load: true)})
    expect_raises(UI::ValidationError) { display.build }.issues.first.path.should eq "blocks[2].elements[0].focus_on_load"
    home = UI::HomeBuilder.new
    home.input(label: UI.plain("Date"), element: date)
    home.section(UI.plain("Time"), accessory: UI::BlockElements::TimePicker.new(focus_on_load: true))
    expect_raises(UI::ValidationError) { home.build }.issues.first.path.should eq "blocks[1].accessory.focus_on_load"
    expect_raises(UI::ValidationError) { UI::Blocks::Actions.new({date, UI::BlockElements::TimePicker.new(action_id: "date")}) }.issues.first.path.should eq "elements[1].action_id"
  end
end

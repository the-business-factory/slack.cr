require "../spec_helper"

module ChannelsSelectSpec
  alias UI = Slack::UI
  alias Single = UI::BlockElements::ChannelsSelect
  alias Multi = UI::BlockElements::MultiChannelsSelect

  describe "Channel selects" do
    it "serializes independently authored single and multiple channel contracts" do
      confirm = UI::CompositionObjects::Confirmation.new(title: UI.plain("Notify?"),
        text: UI.plain("Notify this channel"), confirm: UI.plain("Yes"), deny: UI.plain("No"))
      single = Single.new(action_id: "notification", initial_channel: "C-NOTIFY",
        placeholder: UI.plain("Choose channel", emoji: false), confirm: confirm, focus_on_load: false)
      JSON.parse(single.to_json).should eq JSON.parse(<<-JSON)
        {"type":"channels_select","action_id":"notification","initial_channel":"C-NOTIFY",
         "placeholder":{"type":"plain_text","text":"Choose channel","emoji":false},"focus_on_load":false,
         "confirm":{"title":{"type":"plain_text","text":"Notify?"},"text":{"type":"plain_text","text":"Notify this channel"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
      multi = Multi.new(action_id: "destinations", initial_channels: {"C-ONE", "C-TWO"}, max_selected_items: 2,
        placeholder: UI.plain("Choose destinations"), confirm: confirm, focus_on_load: true)
      JSON.parse(multi.to_json).should eq JSON.parse(<<-JSON)
        {"type":"multi_channels_select","action_id":"destinations","initial_channels":["C-ONE","C-TWO"],"max_selected_items":2,
         "placeholder":{"type":"plain_text","text":"Choose destinations"},"focus_on_load":true,
         "confirm":{"title":{"type":"plain_text","text":"Notify?"},"text":{"type":"plain_text","text":"Notify this channel"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
      JSON.parse(Single.new.to_json).should eq JSON.parse(%({"type":"channels_select"}))
      JSON.parse(Multi.new.to_json).should eq JSON.parse(%({"type":"multi_channels_select"}))
      expect_raises(UI::ValidationError) { Multi.new(initial_channels: [] of String) }.issues.first.path.should eq "initial_channels"
    end

    it "permits response URL configuration only in modal Input blocks" do
      {true, false}.each do |enabled|
        single = Single.new(action_id: "notify", response_url_enabled: enabled)
        JSON.parse(single.to_json).should eq JSON.parse(%({"type":"channels_select","action_id":"notify","response_url_enabled":#{enabled}}))
        expect_raises(UI::ValidationError) { UI::Blocks::Section.new(UI.plain("Notify"), accessory: single) }.issues.first.path.should eq "accessory.response_url_enabled"
        expect_raises(UI::ValidationError) { UI::Blocks::Actions.new({single}) }.issues.first.path.should eq "elements[0].response_url_enabled"
        input = UI::Blocks::Input.new(label: UI.plain("Notify"), element: single)
        UI::FormModal.new(title: UI.plain("Notifications"), submit: UI.plain("Save"), blocks: {input}).validate.should be_empty
        expect_raises(UI::ValidationError) { UI::Message.new(fallback_text: "Notify", blocks: {input}) }.issues.first.path.should eq "blocks[0].element.response_url_enabled"
        expect_raises(UI::ValidationError) { UI::Home.new(blocks: {input}) }.issues.first.path.should eq "blocks[0].element.response_url_enabled"
      end
    end

    it "validates local limits without guessing channel ID formats or remote membership" do
      Single.new(initial_channel: "future-id", action_id: "界" * 255, placeholder: UI.plain("界" * 150)).validate.should be_empty
      Multi.new(initial_channels: {"future-id"}, max_selected_items: 1).validate.should be_empty
      {
        "action_id"           => -> { Single.new(action_id: "界" * 256) },
        "placeholder.text"    => -> { Multi.new(placeholder: UI.plain("界" * 151)) },
        "initial_channel"     => -> { Single.new(initial_channel: "") },
        "initial_channels[0]" => -> { Multi.new(initial_channels: {""}) },
        "initial_channels[1]" => -> { Multi.new(initial_channels: {"C1", "C1"}) },
        "max_selected_items"  => -> { Multi.new(max_selected_items: 0) },
        "initial_channels"    => -> { Multi.new(initial_channels: {"C1", "C2"}, max_selected_items: 1) },
      }.each do |path, construct|
        expect_raises(UI::ValidationError) { construct.call }.issues.first.path.should eq path
      end
    end

    it "composes supported slots and enforces action IDs and view-wide focus" do
      single = Single.new(action_id: "notification", focus_on_load: true)
      multi = Multi.new(action_id: "destinations", focus_on_load: false)
      {UI::MessageBuilder.new(fallback_text: "Notifications"), UI::HomeBuilder.new,
       UI::FormModalBuilder.new(title: UI.plain("Notifications"), submit: UI.plain("Save"))}.each do |builder|
        builder.section(UI.plain("Notification channel"), accessory: single)
        builder.actions({multi})
        builder.input(label: UI.plain("Destinations"), element: multi)
        wire = JSON.parse(builder.build.to_json)
        wire["blocks"][0]["accessory"]["type"].should eq "channels_select"
        wire["blocks"][1]["elements"][0]["type"].should eq "multi_channels_select"
        wire["blocks"][2]["element"]["type"].should eq "multi_channels_select"
      end
      display = UI::DisplayModalBuilder.new(title: UI.plain("Notifications"))
      display.section(UI.plain("Destinations"), accessory: multi)
      display.actions({single})
      display.build.validate.should be_empty
      display.actions({Multi.new(focus_on_load: true)})
      expect_raises(UI::ValidationError) { display.build }.issues.first.path.should eq "blocks[2].elements[0].focus_on_load"
      home = UI::HomeBuilder.new
      home.input(label: UI.plain("Notification channel"), element: single)
      home.section(UI.plain("Note"), accessory: UI::BlockElements::StaticSelect.new(
        options: {UI::CompositionObjects::Option.new(text: UI.plain("X"), value: "x")}, focus_on_load: true))
      expect_raises(UI::ValidationError) { home.build }.issues.first.path.should eq "blocks[1].accessory.focus_on_load"
      expect_raises(UI::ValidationError) { UI::Blocks::Actions.new({single, Multi.new(action_id: "notification")}) }.issues.first.path.should eq "elements[1].action_id"
    end
  end
end

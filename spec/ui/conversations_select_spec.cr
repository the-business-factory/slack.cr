require "../spec_helper"

module ConversationsSelectSpec
  alias UI = Slack::UI
  alias Single = UI::BlockElements::ConversationsSelect
  alias Multi = UI::BlockElements::MultiConversationsSelect

  describe "Conversation selects" do
    it "serializes independently authored single and multiple conversation contracts" do
      confirm = UI::CompositionObjects::Confirmation.new(title: UI.plain("Notify?"),
        text: UI.plain("Notify this conversation"), confirm: UI.plain("Yes"), deny: UI.plain("No"))
      single = Single.new(action_id: "notification", initial_conversation: "C-NOTIFY",
        placeholder: UI.plain("Choose conversation", emoji: false), confirm: confirm, focus_on_load: false)
      JSON.parse(single.to_json).should eq JSON.parse(<<-JSON)
        {"type":"conversations_select","action_id":"notification","initial_conversation":"C-NOTIFY",
         "placeholder":{"type":"plain_text","text":"Choose conversation","emoji":false},"focus_on_load":false,
         "confirm":{"title":{"type":"plain_text","text":"Notify?"},"text":{"type":"plain_text","text":"Notify this conversation"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
      multi = Multi.new(action_id: "destinations", initial_conversations: {"C-ONE", "C-TWO"}, max_selected_items: 2,
        placeholder: UI.plain("Choose destinations"), confirm: confirm, focus_on_load: true)
      JSON.parse(multi.to_json).should eq JSON.parse(<<-JSON)
        {"type":"multi_conversations_select","action_id":"destinations","initial_conversations":["C-ONE","C-TWO"],"max_selected_items":2,
         "placeholder":{"type":"plain_text","text":"Choose destinations"},"focus_on_load":true,
         "confirm":{"title":{"type":"plain_text","text":"Notify?"},"text":{"type":"plain_text","text":"Notify this conversation"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
      JSON.parse(Single.new.to_json).should eq JSON.parse(%({"type":"conversations_select"}))
      JSON.parse(Multi.new.to_json).should eq JSON.parse(%({"type":"multi_conversations_select"}))
      expect_raises(UI::ValidationError) { Multi.new(initial_conversations: [] of String) }.issues.first.path.should eq "initial_conversations"
    end

    it "preserves filters and the distinct single and multi default fields" do
      filter = UI::CompositionObjects::ConversationFilter.new(include: {"im", "mpim", "private", "public"},
        exclude_external_shared_channels: true, exclude_bot_users: false)
      single = Single.new(initial_conversation: "D-ONE", default_to_current_conversation: true, filter: filter)
      JSON.parse(single.to_json).should eq JSON.parse(%({"type":"conversations_select","initial_conversation":"D-ONE","default_to_current_conversation":true,"filter":{"include":["im","mpim","private","public"],"exclude_external_shared_channels":true,"exclude_bot_users":false}}))
      multi = Multi.new(initial_conversations: {"D-ONE"}, default_to_current_conversation: true,
        filter: UI::CompositionObjects::ConversationFilter.new(exclude_bot_users: false))
      JSON.parse(multi.to_json).should eq JSON.parse(%({"type":"multi_conversations_select","initial_conversations":["D-ONE"],"default_to_current_conversation":true,"filter":{"exclude_bot_users":false}}))
      JSON.parse(Single.new(default_to_current_conversation: false).to_json).should eq JSON.parse(%({"type":"conversations_select","default_to_current_conversation":false}))
      JSON.parse(Multi.new(default_to_current_conversation: false).to_json).should eq JSON.parse(%({"type":"multi_conversations_select","default_to_current_conversation":false}))
    end

    it "rejects empty and unsupported filter criteria without requiring true flags" do
      expect_raises(UI::ValidationError) { UI::CompositionObjects::ConversationFilter.new }.issues.first.path.should eq ""
      expect_raises(UI::ValidationError) { UI::CompositionObjects::ConversationFilter.new(include: [] of String) }.issues.first.path.should eq "include"
      expect_raises(UI::ValidationError) { UI::CompositionObjects::ConversationFilter.new(include: {"public", "unknown"}) }.issues.first.path.should eq "include[1]"
      JSON.parse(UI::CompositionObjects::ConversationFilter.new(exclude_external_shared_channels: false).to_json).should eq JSON.parse(%({"exclude_external_shared_channels":false}))
    end

    it "permits response URL configuration only in modal Input blocks" do
      {true, false}.each do |enabled|
        single = Single.new(action_id: "notify", response_url_enabled: enabled)
        JSON.parse(single.to_json).should eq JSON.parse(%({"type":"conversations_select","action_id":"notify","response_url_enabled":#{enabled}}))
        expect_raises(UI::ValidationError) { UI::Blocks::Section.new(UI.plain("Notify"), accessory: single) }.issues.first.path.should eq "accessory.response_url_enabled"
        expect_raises(UI::ValidationError) { UI::Blocks::Actions.new({single}) }.issues.first.path.should eq "elements[0].response_url_enabled"
        input = UI::Blocks::Input.new(label: UI.plain("Notify"), element: single)
        UI::FormModal.new(title: UI.plain("Notifications"), submit: UI.plain("Save"), blocks: {input}).validate.should be_empty
        expect_raises(UI::ValidationError) { UI::Message.new(fallback_text: "Notify", blocks: {input}) }.issues.first.path.should eq "blocks[0].element.response_url_enabled"
        expect_raises(UI::ValidationError) { UI::Home.new(blocks: {input}) }.issues.first.path.should eq "blocks[0].element.response_url_enabled"
      end
    end

    it "validates local limits without guessing conversation ID formats or remote membership" do
      Single.new(initial_conversation: "future-id", action_id: "界" * 255, placeholder: UI.plain("界" * 150)).validate.should be_empty
      Multi.new(initial_conversations: {"future-id"}, max_selected_items: 1).validate.should be_empty
      {
        "action_id"                => -> { Single.new(action_id: "界" * 256) },
        "placeholder.text"         => -> { Multi.new(placeholder: UI.plain("界" * 151)) },
        "initial_conversation"     => -> { Single.new(initial_conversation: "") },
        "initial_conversations[0]" => -> { Multi.new(initial_conversations: {""}) },
        "initial_conversations[1]" => -> { Multi.new(initial_conversations: {"C1", "C1"}) },
        "max_selected_items"       => -> { Multi.new(max_selected_items: 0) },
        "initial_conversations"    => -> { Multi.new(initial_conversations: {"C1", "C2"}, max_selected_items: 1) },
      }.each do |path, construct|
        expect_raises(UI::ValidationError) { construct.call }.issues.first.path.should eq path
      end
    end

    it "composes supported slots and enforces action IDs and view-wide focus" do
      single = Single.new(action_id: "notification", focus_on_load: true)
      multi = Multi.new(action_id: "destinations", focus_on_load: false)
      {UI::MessageBuilder.new(fallback_text: "Notifications"), UI::HomeBuilder.new,
       UI::FormModalBuilder.new(title: UI.plain("Notifications"), submit: UI.plain("Save"))}.each do |builder|
        builder.section(UI.plain("Notification conversation"), accessory: single)
        builder.actions({multi})
        builder.input(label: UI.plain("Destinations"), element: multi)
        wire = JSON.parse(builder.build.to_json)
        wire["blocks"][0]["accessory"]["type"].should eq "conversations_select"
        wire["blocks"][1]["elements"][0]["type"].should eq "multi_conversations_select"
        wire["blocks"][2]["element"]["type"].should eq "multi_conversations_select"
      end
      display = UI::DisplayModalBuilder.new(title: UI.plain("Notifications"))
      display.section(UI.plain("Destinations"), accessory: multi)
      display.actions({single})
      display.build.validate.should be_empty
      display.actions({Multi.new(focus_on_load: true)})
      expect_raises(UI::ValidationError) { display.build }.issues.first.path.should eq "blocks[2].elements[0].focus_on_load"
      home = UI::HomeBuilder.new
      home.input(label: UI.plain("Notification conversation"), element: single)
      home.section(UI.plain("Note"), accessory: UI::BlockElements::StaticSelect.new(
        options: {UI::CompositionObjects::Option.new(text: UI.plain("X"), value: "x")}, focus_on_load: true))
      expect_raises(UI::ValidationError) { home.build }.issues.first.path.should eq "blocks[1].accessory.focus_on_load"
      expect_raises(UI::ValidationError) { UI::Blocks::Actions.new({single, Multi.new(action_id: "notification")}) }.issues.first.path.should eq "elements[1].action_id"
    end
  end
end

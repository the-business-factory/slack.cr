require "../spec_helper"

module UsersSelectSpec
  alias UI = Slack::UI
  alias Single = UI::BlockElements::UsersSelect
  alias Multi = UI::BlockElements::MultiUsersSelect

  describe "User selects" do
    it "serializes independently authored single and multiple user contracts" do
      confirm = UI::CompositionObjects::Confirmation.new(title: UI.plain("Assign?"),
        text: UI.plain("Notify these users"), confirm: UI.plain("Yes"), deny: UI.plain("No"))
      single = Single.new(action_id: "owner", initial_user: "U-OWNER",
        placeholder: UI.plain("Choose owner", emoji: false), confirm: confirm, focus_on_load: false)
      JSON.parse(single.to_json).should eq JSON.parse(<<-JSON)
        {"type":"users_select","action_id":"owner","initial_user":"U-OWNER",
         "placeholder":{"type":"plain_text","text":"Choose owner","emoji":false},"focus_on_load":false,
         "confirm":{"title":{"type":"plain_text","text":"Assign?"},"text":{"type":"plain_text","text":"Notify these users"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
      multi = Multi.new(action_id: "reviewers", initial_users: {"U-ONE", "W-TWO"}, max_selected_items: 2,
        placeholder: UI.plain("Choose reviewers"), confirm: confirm, focus_on_load: true)
      JSON.parse(multi.to_json).should eq JSON.parse(<<-JSON)
        {"type":"multi_users_select","action_id":"reviewers","initial_users":["U-ONE","W-TWO"],"max_selected_items":2,
         "placeholder":{"type":"plain_text","text":"Choose reviewers"},"focus_on_load":true,
         "confirm":{"title":{"type":"plain_text","text":"Assign?"},"text":{"type":"plain_text","text":"Notify these users"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
      JSON.parse(Single.new.to_json).should eq JSON.parse(%({"type":"users_select"}))
      JSON.parse(Multi.new.to_json).should eq JSON.parse(%({"type":"multi_users_select"}))
      JSON.parse(Multi.new(initial_users: [] of String, focus_on_load: false).to_json).should eq JSON.parse(%({"type":"multi_users_select","initial_users":[],"focus_on_load":false}))
    end

    it "validates local limits without guessing user ID formats or remote membership" do
      Single.new(initial_user: "future-id", action_id: "界" * 255, placeholder: UI.plain("界" * 150)).validate.should be_empty
      Multi.new(initial_users: {"future-id"}, max_selected_items: 1).validate.should be_empty
      {
        "action_id"          => -> { Single.new(action_id: "界" * 256) },
        "placeholder.text"   => -> { Multi.new(placeholder: UI.plain("界" * 151)) },
        "initial_user"       => -> { Single.new(initial_user: "") },
        "initial_users[0]"   => -> { Multi.new(initial_users: {""}) },
        "initial_users[1]"   => -> { Multi.new(initial_users: {"U1", "U1"}) },
        "max_selected_items" => -> { Multi.new(max_selected_items: 0) },
        "initial_users"      => -> { Multi.new(initial_users: {"U1", "U2"}, max_selected_items: 1) },
      }.each do |path, construct|
        expect_raises(UI::ValidationError) { construct.call }.issues.first.path.should eq path
      end
    end

    it "composes supported slots and enforces action IDs and view-wide focus" do
      single = Single.new(action_id: "owner", focus_on_load: true)
      multi = Multi.new(action_id: "reviewers", focus_on_load: false)
      {UI::MessageBuilder.new(fallback_text: "Assignment"), UI::HomeBuilder.new,
       UI::FormModalBuilder.new(title: UI.plain("Assignment"), submit: UI.plain("Save"))}.each do |builder|
        builder.section(UI.plain("Owner"), accessory: single)
        builder.actions({multi})
        builder.input(label: UI.plain("Reviewers"), element: multi)
        wire = JSON.parse(builder.build.to_json)
        wire["blocks"][0]["accessory"]["type"].should eq "users_select"
        wire["blocks"][1]["elements"][0]["type"].should eq "multi_users_select"
        wire["blocks"][2]["element"]["type"].should eq "multi_users_select"
      end
      display = UI::DisplayModalBuilder.new(title: UI.plain("Assignment"))
      display.section(UI.plain("Reviewers"), accessory: multi)
      display.actions({single})
      display.build.validate.should be_empty
      display.actions({Multi.new(focus_on_load: true)})
      expect_raises(UI::ValidationError) { display.build }.issues.first.path.should eq "blocks[2].elements[0].focus_on_load"
      home = UI::HomeBuilder.new
      home.input(label: UI.plain("Owner"), element: single)
      home.section(UI.plain("Note"), accessory: UI::BlockElements::StaticSelect.new(
        options: {UI::CompositionObjects::Option.new(text: UI.plain("X"), value: "x")}, focus_on_load: true))
      expect_raises(UI::ValidationError) { home.build }.issues.first.path.should eq "blocks[1].accessory.focus_on_load"
      expect_raises(UI::ValidationError) { UI::Blocks::Actions.new({single, Multi.new(action_id: "owner")}) }.issues.first.path.should eq "elements[1].action_id"
    end
  end
end

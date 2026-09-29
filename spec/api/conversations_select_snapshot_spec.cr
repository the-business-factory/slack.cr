require "../spec_helper"
require "../support/one_pass"

module ConversationsSelectSnapshotSpec
  alias UI = Slack::UI

  it "sends owned conversation selections after caller, getter, and builder mutation" do
    ids = ["C-ONE", "G-TWO"]
    conversations = SpecSupport::OnePass.new(ids)
    multi = UI::BlockElements::MultiConversationsSelect.new(action_id: "destinations", initial_conversations: conversations,
      max_selected_items: 3, focus_on_load: false)
    kinds = ["public", "private", "im"]
    includes = SpecSupport::OnePass.new(kinds)
    filter = UI::CompositionObjects::ConversationFilter.new(include: includes, exclude_bot_users: false)
    single = UI::BlockElements::ConversationsSelect.new(action_id: "notification", initial_conversation: "D-NOTIFY", response_url_enabled: true,
      default_to_current_conversation: false, filter: filter)
    builder = UI::FormModalBuilder.new(title: UI.plain("Notifications"), submit: UI.plain("Save"))
    builder.input(label: UI.plain("Notify"), element: single, block_id: "notification")
    builder.input(label: UI.plain("Destinations"), element: multi, block_id: "destinations",
      optional: true, dispatch_action: false)
    request = Slack::Api::ViewsOpen.new(trigger_id: "synthetic-trigger",
      view: builder.build)
    ids.clear
    kinds.clear
    filter_copy = filter
    filter_copy.include.should_not(be_nil).clear
    single.filter.should_not(be_nil).include.should_not(be_nil).clear
    includes.passes.should eq 1
    copy = multi
    copy.initial_conversations.should_not(be_nil).clear
    builder.divider
    conversations.passes.should eq 1
    # Independently authored from the documented conversation fields and request envelope.
    expected = JSON.parse(<<-JSON)
      {"trigger_id":"synthetic-trigger","view":{"type":"modal","title":{"type":"plain_text","text":"Notifications"},"submit":{"type":"plain_text","text":"Save"},
       "blocks":[{"type":"input","label":{"type":"plain_text","text":"Notify"},"block_id":"notification",
         "element":{"type":"conversations_select","action_id":"notification","initial_conversation":"D-NOTIFY","response_url_enabled":true,"default_to_current_conversation":false,"filter":{"include":["public","private","im"],"exclude_bot_users":false}}},
        {"type":"input","label":{"type":"plain_text","text":"Destinations"},"block_id":"destinations","optional":true,"dispatch_action":false,
         "element":{"type":"multi_conversations_select","action_id":"destinations","initial_conversations":["C-ONE","G-TWO"],"max_selected_items":3,"focus_on_load":false}}]}}
      JSON
    JSON.parse(request.to_json).should eq expected
  end
end

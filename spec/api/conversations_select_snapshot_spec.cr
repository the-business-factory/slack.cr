require "../spec_helper"
require "../support/auth/webmock_transport"

module ConversationsSelectSnapshotSpec
  alias UI = Slack::UI

  class OnePassConversations
    include Enumerable(String?)
    getter passes : Int32 = 0

    def initialize(@items : Array(String))
    end

    def each(&) : Nil
      @passes += 1
      raise "Traversed twice" if @passes > 1
      @items.each { |item| yield item }
    end
  end

  it "sends owned conversation selections after caller, getter, and builder mutation" do
    ids = ["C-ONE", "G-TWO"]
    conversations = OnePassConversations.new(ids)
    multi = UI::BlockElements::MultiConversationsSelect.new(action_id: "destinations", initial_conversations: conversations,
      max_selected_items: 3, focus_on_load: false)
    kinds = ["public", "private", "im"]
    includes = OnePassConversations.new(kinds)
    filter = UI::CompositionObjects::ConversationFilter.new(include: includes, exclude_bot_users: false)
    single = UI::BlockElements::ConversationsSelect.new(action_id: "notification", initial_conversation: "D-NOTIFY", response_url_enabled: true,
      default_to_current_conversation: false, filter: filter)
    builder = UI::FormModalBuilder.new(title: UI.plain("Notifications"), submit: UI.plain("Save"))
    builder.input(label: UI.plain("Notify"), element: single, block_id: "notification")
    builder.input(label: UI.plain("Destinations"), element: multi, block_id: "destinations",
      optional: true, dispatch_action: false)
    request = Slack::Api::ViewsOpen.new(token: "xoxb-synthetic", trigger_id: "synthetic-trigger",
      view: builder.build, transport: AuthSupport::WebMockTransport.new)
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
    sent = 0
    WebMock.stub(:post, "https://slack.com/api/views.open").with(headers: {"Authorization" => "Bearer xoxb-synthetic"}).to_return do |http_request|
      sent += 1
      JSON.parse(http_request.body || fail("Missing body")).should eq expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V-SYNTHETIC","type":"modal"}}))
    end
    request.call.view["id"].should eq "V-SYNTHETIC"
    sent.should eq 1
  end
end

require "../spec_helper"
require "../support/auth/webmock_transport"

module UsersSelectSnapshotSpec
  alias UI = Slack::UI

  class OnePassUsers
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

  it "sends owned user selections after caller, getter, and builder mutation" do
    ids = ["U-ONE", "W-TWO"]
    users = OnePassUsers.new(ids)
    multi = UI::BlockElements::MultiUsersSelect.new(action_id: "reviewers", initial_users: users,
      max_selected_items: 3, focus_on_load: false)
    single = UI::BlockElements::UsersSelect.new(action_id: "owner", initial_user: "U-OWNER")
    builder = UI::MessageBuilder.new(fallback_text: "Assign request")
    builder.section(UI.plain("Owner"), accessory: single, block_id: "assignment")
    builder.input(label: UI.plain("Reviewers"), element: multi, block_id: "review",
      optional: true, dispatch_action: false)
    request = Slack::Api::ChatPostMessage.new(token: "xoxb-synthetic", channel: "C-SYNTHETIC",
      message: builder.build, unfurl_links: false, transport: AuthSupport::WebMockTransport.new)
    ids.clear
    copy = multi
    copy.initial_users.should_not(be_nil).clear
    builder.divider
    users.passes.should eq 1
    # Independently authored from the documented user fields and request envelope.
    expected = JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Assign request","unfurl_links":false,
       "blocks":[{"type":"section","text":{"type":"plain_text","text":"Owner"},"block_id":"assignment",
         "accessory":{"type":"users_select","action_id":"owner","initial_user":"U-OWNER"}},
        {"type":"input","label":{"type":"plain_text","text":"Reviewers"},"block_id":"review","optional":true,"dispatch_action":false,
         "element":{"type":"multi_users_select","action_id":"reviewers","initial_users":["U-ONE","W-TWO"],"max_selected_items":3,"focus_on_load":false}}]}
      JSON
    JSON.parse(request.to_json).should eq expected
    sent = 0
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").with(headers: {"Authorization" => "Bearer xoxb-synthetic"}).to_return do |http_request|
      sent += 1
      JSON.parse(http_request.body || fail("Missing body")).should eq expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000001","message":{}}))
    end
    request.call.channel.should eq "C-SYNTHETIC"
    sent.should eq 1
  end
end

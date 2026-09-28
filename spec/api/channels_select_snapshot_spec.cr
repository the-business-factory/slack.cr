require "../spec_helper"
require "../support/auth/webmock_transport"

module ChannelsSelectSnapshotSpec
  alias UI = Slack::UI::Checked

  class OnePassChannels
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

  it "sends owned channel selections after caller, getter, and builder mutation" do
    ids = ["C-ONE", "C-TWO"]
    channels = OnePassChannels.new(ids)
    multi = UI::BlockElements::MultiChannelsSelect.new(action_id: "destinations", initial_channels: channels,
      max_selected_items: 3, focus_on_load: false)
    single = UI::BlockElements::ChannelsSelect.new(action_id: "notification", initial_channel: "C-NOTIFY", response_url_enabled: true)
    builder = UI::FormModalBuilder.new(title: UI.plain("Notifications"), submit: UI.plain("Save"))
    builder.input(label: UI.plain("Notify"), element: single, block_id: "notification")
    builder.input(label: UI.plain("Destinations"), element: multi, block_id: "destinations",
      optional: true, dispatch_action: false)
    request = Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic", trigger_id: "synthetic-trigger",
      view: builder.build, transport: AuthSupport::WebMockTransport.new)
    ids.clear
    copy = multi
    copy.initial_channels.should_not(be_nil).clear
    builder.divider
    channels.passes.should eq 1
    # Independently authored from the documented channel fields and request envelope.
    expected = JSON.parse(<<-JSON)
      {"trigger_id":"synthetic-trigger","view":{"type":"modal","title":{"type":"plain_text","text":"Notifications"},"submit":{"type":"plain_text","text":"Save"},
       "blocks":[{"type":"input","label":{"type":"plain_text","text":"Notify"},"block_id":"notification",
         "element":{"type":"channels_select","action_id":"notification","initial_channel":"C-NOTIFY","response_url_enabled":true}},
        {"type":"input","label":{"type":"plain_text","text":"Destinations"},"block_id":"destinations","optional":true,"dispatch_action":false,
         "element":{"type":"multi_channels_select","action_id":"destinations","initial_channels":["C-ONE","C-TWO"],"max_selected_items":3,"focus_on_load":false}}]}}
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

require "../spec_helper"
require "../support/one_pass"

module ChannelsSelectSnapshotSpec
  alias UI = Slack::UI

  it "sends owned channel selections after caller, getter, and builder mutation" do
    ids = ["C-ONE", "C-TWO"]
    channels = SpecSupport::OnePass.new(ids)
    multi = UI::BlockElements::MultiChannelsSelect.new(action_id: "destinations", initial_channels: channels,
      max_selected_items: 3, focus_on_load: false)
    single = UI::BlockElements::ChannelsSelect.new(action_id: "notification", initial_channel: "C-NOTIFY", response_url_enabled: true)
    builder = UI::FormModalBuilder.new(title: UI.plain("Notifications"), submit: UI.plain("Save"))
    builder.input(label: UI.plain("Notify"), element: single, block_id: "notification")
    builder.input(label: UI.plain("Destinations"), element: multi, block_id: "destinations",
      optional: true, dispatch_action: false)
    request = Slack::Api::ViewsOpen.new(trigger_id: "synthetic-trigger",
      view: builder.build)
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
  end
end

require "../spec_helper"
require "../support/api/webmock_client"
require "../support/one_pass"

module CheckboxesSnapshotSpec
  alias UI = Slack::UI
  alias Option = UI::CompositionObjects::CheckboxOption

  it "sends owned checkbox choices and initial selections after caller mutation" do
    options = [Option.new(text: UI.mrkdwn("*Digest*"), value: "digest")]
    initial = options.dup
    choices = SpecSupport::OnePass.new(options)
    selections = SpecSupport::OnePass.new(initial)
    control = UI::BlockElements::Checkboxes.new(options: choices, initial_options: selections, action_id: "notifications")
    builder = UI::MessageBuilder.new(fallback_text: "Preferences")
    builder.input(label: UI.plain("Notifications"), element: control, block_id: "preferences", optional: true)
    request = Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: builder.build)
    options.clear
    initial.clear
    copy = control
    copy.options.clear
    copy.initial_options.try(&.clear)
    builder.divider
    choices.passes.should eq 1
    selections.passes.should eq 1
    expected = JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Preferences","blocks":[{"type":"input","label":{"type":"plain_text","text":"Notifications"},"block_id":"preferences","optional":true,"element":{"type":"checkboxes","action_id":"notifications","options":[{"text":{"type":"mrkdwn","text":"*Digest*"},"value":"digest"}],"initial_options":[{"text":{"type":"mrkdwn","text":"*Digest*"},"value":"digest"}]}}]}
      JSON
    JSON.parse(request.to_json).should eq expected
  end

  it "rejects invalid checkbox choices before transport" do
    sent = 0
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do
      sent += 1
      HTTP::Client::Response.new(200, body: %({"ok":true}))
    end
    expect_raises(UI::ValidationError) do
      message = UI.message(fallback_text: "Preferences") do |builder|
        builder.input(label: UI.plain("Notifications"), element: UI::BlockElements::Checkboxes.new(options: [] of Option))
      end
      ApiSupport.client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))
    end.issues.first.code.should eq "checkboxes.options.size"
    sent.should eq 0
  end
end

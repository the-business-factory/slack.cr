require "../spec_helper"
require "../support/api/webmock_client"

module CheckboxesSnapshotSpec
  alias UI = Slack::UI
  alias Option = UI::CompositionObjects::CheckboxOption

  class OnePassOptions
    include Enumerable(Option?)
    getter passes : Int32 = 0

    def initialize(@items : Array(Option))
    end

    def each(&) : Nil
      @passes += 1
      raise "Traversed twice" if @passes > 1
      @items.each { |item| yield item }
    end
  end

  it "sends owned checkbox choices and initial selections after caller mutation" do
    options = [Option.new(text: UI.mrkdwn("*Digest*"), value: "digest")]
    initial = options.dup
    choices = OnePassOptions.new(options)
    selections = OnePassOptions.new(initial)
    control = UI::BlockElements::Checkboxes.new(options: choices, initial_options: selections, action_id: "notifications")
    builder = UI::MessageBuilder.new(fallback_text: "Preferences")
    builder.input(label: UI.plain("Notifications"), element: control, block_id: "preferences", optional: true)
    client = ApiSupport.client("xoxb-synthetic")
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
    sent = 0
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").with(headers: {"Authorization" => "Bearer xoxb-synthetic"}).to_return do |http_request|
      sent += 1
      JSON.parse(http_request.body || fail("Missing body")).should eq expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000001","message":{"type":"message","ts":"1710000000.000001"}}))
    end
    client.call(request).channel.should eq "C-SYNTHETIC"
    sent.should eq 1
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

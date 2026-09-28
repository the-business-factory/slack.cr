require "../spec_helper"
require "../support/api/webmock_client"

module RadioButtonsSnapshotSpec
  alias UI = Slack::UI
  alias Option = UI::CompositionObjects::RadioOption

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

  it "sends an owned radio choice and initial selection after caller mutation" do
    digest = Option.new(text: UI.mrkdwn("*Digest*"), value: "digest")
    options = [digest, Option.new(text: UI.plain("Immediate"), value: "immediate")]
    choices = OnePassOptions.new(options)
    control = UI::BlockElements::RadioButtons.new(options: choices, initial_option: digest,
      action_id: "delivery", focus_on_load: false)
    builder = UI::MessageBuilder.new(fallback_text: "Delivery preference")
    builder.input(label: UI.plain("Delivery"), element: control, block_id: "preferences",
      optional: true, dispatch_action: true)
    client = ApiSupport.client("xoxb-synthetic")
    request = Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC",
      message: builder.build, unfurl_links: false)
    options.clear
    copy = control
    copy.options.clear
    builder.divider
    choices.passes.should eq 1
    # Authored from Slack's radio, option, Input, and chat.postMessage contracts.
    expected = JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Delivery preference","unfurl_links":false,
       "blocks":[{"type":"input","label":{"type":"plain_text","text":"Delivery"},
       "block_id":"preferences","optional":true,"dispatch_action":true,
       "element":{"type":"radio_buttons","action_id":"delivery","focus_on_load":false,
       "options":[{"text":{"type":"mrkdwn","text":"*Digest*"},"value":"digest"},
                  {"text":{"type":"plain_text","text":"Immediate"},"value":"immediate"}],
       "initial_option":{"text":{"type":"mrkdwn","text":"*Digest*"},"value":"digest"}}}]}
      JSON
    JSON.parse(request.to_json).should eq expected
    sent = 0
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").with(headers: {"Authorization" => "Bearer xoxb-synthetic"}).to_return do |http_request|
      sent += 1
      JSON.parse(http_request.body || fail("Missing body")).should eq expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000001","message":{}}))
    end
    client.call(request).channel.should eq "C-SYNTHETIC"
    sent.should eq 1
  end
end

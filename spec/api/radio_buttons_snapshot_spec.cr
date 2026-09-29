require "../spec_helper"
require "../support/one_pass"

module RadioButtonsSnapshotSpec
  alias UI = Slack::UI
  alias Option = UI::CompositionObjects::RadioOption

  it "sends an owned radio choice and initial selection after caller mutation" do
    digest = Option.new(text: UI.mrkdwn("*Digest*"), value: "digest")
    options = [digest, Option.new(text: UI.plain("Immediate"), value: "immediate")]
    choices = SpecSupport::OnePass.new(options)
    control = UI::BlockElements::RadioButtons.new(options: choices, initial_option: digest,
      action_id: "delivery", focus_on_load: false)
    builder = UI::MessageBuilder.new(fallback_text: "Delivery preference")
    builder.input(label: UI.plain("Delivery"), element: control, block_id: "preferences",
      optional: true, dispatch_action: true)
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
  end
end

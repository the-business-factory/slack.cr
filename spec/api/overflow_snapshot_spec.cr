require "../spec_helper"

module OverflowSnapshotSpec
  alias UI = Slack::UI

  describe "Overflow at the message boundary" do
    it "sends an owned snapshot after callers mutate the options, elements, and builder" do
      options = [UI::CompositionObjects::OverflowOption.new(text: UI.plain("Archive"), value: "archive")]
      menu = UI::BlockElements::Overflow.new(options: options, action_id: "more")
      elements = [menu]
      actions = UI::Blocks::Actions.new(elements, block_id: "request")
      builder = UI::MessageBuilder.new(fallback_text: "Request actions")
      builder.add(actions)
      request = Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: builder.build)
      options.clear
      menu.options.clear
      elements.clear
      actions.elements.clear
      builder.divider
      expected = JSON.parse(File.read("spec/fixtures/block_kit/overflow_chat_postMessage.json"))
      JSON.parse(request.to_json).should eq expected
    end
  end
end

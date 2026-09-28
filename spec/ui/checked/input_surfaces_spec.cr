require "../../spec_helper"

module InputSurfacesSpec
  alias UI = Slack::UI::Checked

  # Authored independently of the serializers; preserve false, omission and order.
  BLOCKS = <<-JSON
    [
      {"type":"input","label":{"type":"plain_text","text":"Note"},"element":{"type":"plain_text_input","action_id":"note","multiline":false,"focus_on_load":false},"block_id":"note-block","optional":false,"dispatch_action":false},
      {"type":"input","label":{"type":"plain_text","text":"One"},"element":{"type":"static_select","options":[{"text":{"type":"plain_text","text":"Choice"},"value":"choice"}],"action_id":"one","focus_on_load":false},"block_id":"one-block"},
      {"type":"input","label":{"type":"plain_text","text":"Many"},"element":{"type":"multi_static_select","options":[{"text":{"type":"plain_text","text":"Choice"},"value":"choice"}],"initial_options":[],"action_id":"many"},"block_id":"many-block","optional":true}
    ]
    JSON

  def self.inputs : Array(UI::Blocks::Input)
    option = UI::CompositionObjects::Option.new(text: UI.plain("Choice"), value: "choice")
    [
      UI::Blocks::Input.new(label: UI.plain("Note"), element: UI::BlockElements::PlainTextInput.new(action_id: "note", multiline: false, focus_on_load: false), block_id: "note-block", optional: false, dispatch_action: false),
      UI::Blocks::Input.new(label: UI.plain("One"), element: UI::BlockElements::StaticSelect.new(options: [option], action_id: "one", focus_on_load: false), block_id: "one-block"),
      UI::Blocks::Input.new(label: UI.plain("Many"), element: UI::BlockElements::MultiStaticSelect.new(options: [option], initial_options: [] of UI::CompositionObjects::Option, action_id: "many"), block_id: "many-block", optional: true),
    ]
  end

  describe "Input surface payloads" do
    it "serializes all supported inputs directly and through the Message helper" do
      expected = JSON.parse(%({"text":"Inputs","blocks":#{BLOCKS}}))
      direct = UI::Message.new(fallback_text: "Inputs", blocks: inputs)
      built = UI.message(fallback_text: "Inputs") do |builder|
        inputs.each do |input|
          builder.input(label: input.label, element: input.element, block_id: input.block_id, optional: input.optional, dispatch_action: input.dispatch_action)
        end
      end
      JSON.parse(direct.to_json).should eq expected
      JSON.parse(built.to_json).should eq expected
      generated = UI::Message.with_slack_generated_fallback(blocks: inputs)
      JSON.parse(generated.to_json).should eq JSON.parse(%({"blocks":#{BLOCKS}}))
    end

    it "preserves Home and FormModal input support through direct and builder APIs" do
      home = UI::Home.new(blocks: inputs)
      built_home = UI.home(&.add_all(inputs))
      form = UI::FormModal.new(title: UI.plain("Form"), submit: UI.plain("Save"), blocks: inputs)
      built_form = UI.form_modal(title: UI.plain("Form"), submit: UI.plain("Save")) { |builder| builder.add_all(inputs) }
      expected_home = JSON.parse(%({"type":"home","blocks":#{BLOCKS}}))
      expected_form = JSON.parse(%({"type":"modal","title":{"type":"plain_text","text":"Form"},"submit":{"type":"plain_text","text":"Save"},"blocks":#{BLOCKS}}))
      JSON.parse(home.to_json).should eq expected_home
      JSON.parse(built_home.to_json).should eq expected_home
      JSON.parse(form.to_json).should eq expected_form
      JSON.parse(built_form.to_json).should eq expected_form
    end

    it "keeps Message inputs after caller, getter and builder mutation" do
      caller_blocks = inputs
      message = UI::Message.new(fallback_text: "Inputs", blocks: caller_blocks)
      builder = UI::MessageBuilder.new(fallback_text: "Inputs")
      builder.add_all(caller_blocks)
      first = builder.build
      caller_blocks.clear
      message.blocks.clear
      first.blocks.clear
      builder.divider
      expected = JSON.parse(%({"text":"Inputs","blocks":#{BLOCKS}}))
      JSON.parse(message.to_json).should eq expected
      JSON.parse(first.to_json).should eq expected
    end
  end
end

module SurfaceConsumer
  alias UI = Slack::UI::Checked

  def self.kind(block : UI::MessageBlock) : String
    case block
    in UI::Blocks::Input
      "input"
    in UI::Blocks::File
      "message-only"
    in UI::DisplayModalBlock
      "display"
    end
  end

  def self.caption(block : UI::Blocks::Input) : String
    block.label.text
  end

  def self.caption(block : UI::Blocks::File) : String
    block.external_id
  end

  def self.caption(block : UI::DisplayModalBlock) : String
    block.type
  end
end

describe "typed surface consumers" do
  it "dispatches Input, message-only, and display blocks through exhaustive cases and overloads" do
    input = Slack::UI::Checked::Blocks::Input.new(
      label: Slack::UI::Checked.plain("Note"),
      element: Slack::UI::Checked::BlockElements::PlainTextInput.new
    )
    display_blocks = [Slack::UI::Checked::Blocks::Divider.new] of Slack::UI::Checked::DisplayModalBlock
    file = Slack::UI::Checked::Blocks::File.new(external_id: "ABCD1")
    message_blocks = [display_blocks.first, input, file] of Slack::UI::Checked::MessageBlock
    consumer_message = Slack::UI::Checked::Message.new(fallback_text: "Note", blocks: message_blocks)
    Slack::UI::Checked::DisplayModal.new(title: Slack::UI::Checked.plain("Display"), blocks: display_blocks)
    consumer_message.blocks.map { |block| SurfaceConsumer.kind(block) }.should eq(["display", "input", "message-only"])
    consumer_message.blocks.map { |block| SurfaceConsumer.caption(block) }.should eq(["divider", "Note", "ABCD1"])
  end
end

require "../spec_helper"

module InputSurfacesSpec
  alias UI = Slack::UI

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
  alias UI = Slack::UI

  def self.kind(block : UI::MessageBlock) : String
    case block
    in UI::Blocks::Input
      "input"
    in UI::Blocks::File, UI::Blocks::Markdown, UI::Blocks::ContextActions
      "message-only"
    in UI::Blocks::Table, UI::Blocks::DataTable
      "table"
    in UI::Blocks::DataVisualization
      "chart"
    in UI::Blocks::Carousel
      "carousel"
    in UI::Blocks::Container
      "container"
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

  def self.caption(block : UI::Blocks::Markdown) : String
    block.text
  end

  def self.caption(block : UI::DisplayModalBlock | UI::Blocks::Table | UI::Blocks::ContextActions | UI::Blocks::DataTable | UI::Blocks::DataVisualization | UI::Blocks::Carousel) : String
    block.type
  end

  def self.caption(block : UI::Blocks::Container) : String
    block.child_blocks.size.to_s
  end
end

describe "typed surface consumers" do
  it "dispatches Input, message-only, table, carousel, container, and display blocks through exhaustive cases and overloads" do
    input = Slack::UI::Blocks::Input.new(
      label: Slack::UI.plain("Note"),
      element: Slack::UI::BlockElements::PlainTextInput.new
    )
    divider = Slack::UI::Blocks::Divider.new
    # DisplayModalBlock includes the modal-only Alert, so share concrete display blocks.
    display_blocks = [divider] of Slack::UI::DisplayModalBlock
    file = Slack::UI::Blocks::File.new(external_id: "ABCD1")
    table = Slack::UI::Blocks::Table.new(rows: { {Slack::UI::Table::RawText.new("Open")} })
    markdown = Slack::UI::Blocks::Markdown.new("**Open**")
    trash = Slack::UI::BlockElements::IconButton.new(Slack::UI::BlockElements::IconButtonIcon::Trash, text: Slack::UI.plain("Delete"))
    context_actions = Slack::UI::Blocks::ContextActions.new(elements: {trash})
    data_table = Slack::UI::Blocks::DataTable.new(caption: "Queue", header: {Slack::UI::Table::RawText.new("Ticket")},
      rows: { {Slack::UI::Table::RawText.new("T-1")} })
    card = Slack::UI::Blocks::Card.new(title: Slack::UI.plain("Card"))
    carousel = Slack::UI::Blocks::Carousel.new(elements: {card})
    container = Slack::UI::Blocks::Container.new(title: Slack::UI.plain("Group"), child_blocks: {file, input})
    message_blocks = [divider, input, file, table, markdown, context_actions, data_table, carousel, container] of Slack::UI::MessageBlock
    consumer_message = Slack::UI::Message.new(fallback_text: "Note", blocks: message_blocks)
    Slack::UI::DisplayModal.new(title: Slack::UI.plain("Display"), blocks: display_blocks)
    consumer_message.blocks.map { |block| SurfaceConsumer.kind(block) }.should eq(["display", "input", "message-only", "table", "message-only", "message-only", "table", "carousel", "container"])
    consumer_message.blocks.map { |block| SurfaceConsumer.caption(block) }.should eq(["divider", "Note", "ABCD1", "table", "**Open**", "context_actions", "data_table", "carousel", "2"])
  end
end

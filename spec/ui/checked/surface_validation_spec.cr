require "../../spec_helper"

alias SurfaceUI = Slack::UI::Checked

describe "Checked surface validation order" do
  it "reports every repeated ID, including empty IDs, across block types on each surface" do
    builders = {
      {SurfaceUI::MessageBuilder.new(fallback_text: "Summary"), "message", "message"},
      {SurfaceUI::DisplayModalBuilder.new(title: SurfaceUI.plain("Display")), "modal", "view"},
      {SurfaceUI::FormModalBuilder.new(title: SurfaceUI.plain("Form"), submit: SurfaceUI.plain("Send")), "modal", "view"},
      {SurfaceUI::HomeBuilder.new, "home", "view"},
    }
    builders.each do |builder, surface, container|
      builder.divider(block_id: "")
      builder.header(text: SurfaceUI.plain("First"), block_id: "same")
      builder.divider
      builder.section(SurfaceUI.plain("Second"), block_id: "")
      builder.divider(block_id: "same")
      builder.divider
      builder.context(elements: {SurfaceUI.plain("Third")}, block_id: "same")

      error = expect_raises(SurfaceUI::ValidationError) { builder.build }
      expected = [3, 4, 6].map do |index|
        SurfaceUI::ValidationIssue.new("#{surface}.block_id.duplicate", "blocks[#{index}].block_id", "Block IDs must be unique within a #{container}.")
      end
      error.issues.should eq expected
    end
  end

  it "reports view envelope and block errors before focus errors on both modal types and Home" do
    builders = {
      {SurfaceUI::DisplayModalBuilder.new(title: SurfaceUI.plain("Display"), callback_id: "x" * 256), "modal", "A modal"},
      {SurfaceUI::FormModalBuilder.new(title: SurfaceUI.plain("Form"), submit: SurfaceUI.plain("Send"), callback_id: "x" * 256), "modal", "A modal"},
      {SurfaceUI::HomeBuilder.new(callback_id: "x" * 256), "home", "Home"},
    }
    option = SurfaceUI::CompositionObjects::Option.new(text: SurfaceUI.plain("Choice"), value: "choice")
    menu = SurfaceUI::BlockElements::StaticSelect.new(options: {option}, focus_on_load: true)
    builders.each do |builder, surface, label|
      builder.section(SurfaceUI.plain("First"), accessory: menu, block_id: "same")
      builder.actions(elements: {menu}, block_id: "same")
      builder.divider(block_id: "same")
      98.times { builder.divider }

      error = expect_raises(SurfaceUI::ValidationError) { builder.build }
      error.issues.should eq [
        SurfaceUI::ValidationIssue.new("#{surface}.callback_id.too_long", "callback_id", "Value cannot be longer than 255 characters."),
        SurfaceUI::ValidationIssue.new("#{surface}.blocks.too_many", "blocks", "#{label} cannot contain more than 100 blocks."),
        SurfaceUI::ValidationIssue.new("#{surface}.block_id.duplicate", "blocks[1].block_id", "Block IDs must be unique within a view."),
        SurfaceUI::ValidationIssue.new("#{surface}.block_id.duplicate", "blocks[2].block_id", "Block IDs must be unique within a view."),
        SurfaceUI::ValidationIssue.new("#{surface}.focus_on_load.duplicate", "blocks[1].elements[0].focus_on_load", "Only one element in a view can focus on load."),
      ]
      error.message.should eq "callback_id: Value cannot be longer than 255 characters.; blocks: #{label} cannot contain more than 100 blocks.; blocks[1].block_id: Block IDs must be unique within a view.; blocks[2].block_id: Block IDs must be unique within a view.; blocks[1].elements[0].focus_on_load: Only one element in a view can focus on load."
    end
  end

  it "keeps message count and fallback errors ahead of duplicate IDs without applying view focus rules" do
    builder = SurfaceUI::MessageBuilder.new(fallback_text: "")
    option = SurfaceUI::CompositionObjects::Option.new(text: SurfaceUI.plain("Choice"), value: "choice")
    menu = SurfaceUI::BlockElements::StaticSelect.new(options: {option}, focus_on_load: true)
    builder.section(SurfaceUI.plain("First"), accessory: menu, block_id: "same")
    builder.actions(elements: {menu}, block_id: "same")
    49.times { builder.divider }

    error = expect_raises(SurfaceUI::ValidationError) { builder.build }
    error.issues.should eq [
      SurfaceUI::ValidationIssue.new("message.blocks.too_many", "blocks", "A message cannot contain more than 50 blocks."),
      SurfaceUI::ValidationIssue.new("message.fallback_text.empty", "fallback_text", "Fallback text must not be empty."),
      SurfaceUI::ValidationIssue.new("message.block_id.duplicate", "blocks[1].block_id", "Block IDs must be unique within a message."),
    ]
  end

  it "allows omitted block IDs and repeated action IDs in separate blocks on every surface" do
    button = SurfaceUI::BlockElements::Button.new(text: SurfaceUI.plain("Go"), action_id: "same")
    builders = {
      SurfaceUI::MessageBuilder.new(fallback_text: "Summary"),
      SurfaceUI::DisplayModalBuilder.new(title: SurfaceUI.plain("Display")),
      SurfaceUI::FormModalBuilder.new(title: SurfaceUI.plain("Form"), submit: SurfaceUI.plain("Send")),
      SurfaceUI::HomeBuilder.new,
    }
    builders.each do |builder|
      2.times { builder.actions(elements: {button}) }
      surface = builder.build
      surface.validate.should be_empty
      surface.snapshot.validate.should be_empty
      JSON.parse(surface.to_json)["blocks"].as_a.size.should eq 2
    end
  end
end

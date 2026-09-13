require "../../spec_helper"

private alias DisplayUI = Slack::UI::Checked

describe "Checked display blocks and images" do
  it "serializes all display fields and all three image sources" do
    header = DisplayUI::Blocks::Header.new(text: DisplayUI.plain("Overview", emoji: false), block_id: "heading", level: 2)
    file = DisplayUI::CompositionObjects::SlackFile.new(id: "F123")
    thumbnail = DisplayUI::BlockElements::Image.new(slack_file: file, alt_text: "Project thumbnail")
    context = DisplayUI::Blocks::Context.new(elements: {DisplayUI.plain("Status", emoji: false), DisplayUI.mrkdwn("*Ready*", verbatim: false), thumbnail}, block_id: "status")
    image = DisplayUI::Blocks::Image.new(image_url: "https://example.test/project.png", alt_text: "Project diagram", title: DisplayUI.plain("Diagram", emoji: true), block_id: "diagram")
    private_image = DisplayUI::Blocks::Image.new(slack_file: DisplayUI::CompositionObjects::SlackFile.new(url: "https://files.slack.com/files-pri/T123-F123/project.png"), alt_text: "Private diagram")
    JSON.parse({header, context, image, private_image}.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/phase_4_display.json"))
  end

  it "omits optional fields and accepts both Slack file locators in both image roles" do
    JSON.parse(DisplayUI::Blocks::Header.new(text: DisplayUI.plain("Heading")).to_json).should eq JSON.parse(%({"type":"header","text":{"type":"plain_text","text":"Heading"}}))
    JSON.parse(DisplayUI::Blocks::Context.new(elements: [DisplayUI.plain("Context")]).to_json).as_h.keys.sort!.should eq %w[elements type]
    {DisplayUI::CompositionObjects::SlackFile.new(id: "F123"), DisplayUI::CompositionObjects::SlackFile.new(url: "https://files.slack.com/a")}.each do |file|
      block = DisplayUI::Blocks::Image.new(slack_file: file, alt_text: "Image")
      element = DisplayUI::BlockElements::Image.new(slack_file: file, alt_text: "Image")
      {block, element}.each do |node|
        payload = JSON.parse(node.to_json)
        payload.as_h.keys.sort!.should eq %w[alt_text slack_file type]
        payload["slack_file"].should eq JSON.parse(file.to_json)
      end
    end
    element = DisplayUI::BlockElements::Image.new(image_url: "https://example.test/a.png", alt_text: "Image")
    JSON.parse(element.to_json).as_h.keys.sort!.should eq %w[alt_text image_url type]
  end

  it "counts header characters and validates both heading level boundaries" do
    DisplayUI::Blocks::Header.new(text: DisplayUI.plain("界" * 150), block_id: "界" * 255).validate.should be_empty
    [1, 2, 3, 4].each { |level| DisplayUI::Blocks::Header.new(text: DisplayUI.plain("Heading"), level: level).level.should eq level }
    [0, 5].each do |level|
      error = expect_raises(DisplayUI::ValidationError) { DisplayUI::Blocks::Header.new(text: DisplayUI.plain("Heading"), level: level) }
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"header.level.invalid", "level"}]
    end
    error = expect_raises(DisplayUI::ValidationError) { DisplayUI::Blocks::Header.new(text: DisplayUI.plain("界" * 151), block_id: "界" * 256) }
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"header.text.too_long", "text.text"}, {"header.block_id.too_long", "block_id"}]
  end

  [0, 1, 10, 11].each do |size|
    it "checks a dynamic Context with #{size} elements" do
      elements = Array.new(size) { DisplayUI.plain("Context") }
      if 1 <= size <= 10
        DisplayUI::Blocks::Context.new(elements: elements, block_id: "界" * 255).elements.size.should eq size
      else
        error = expect_raises(DisplayUI::ValidationError) { DisplayUI::Blocks::Context.new(elements: elements) }
        error.issues.map(&.code).should eq [size == 0 ? "context.elements.empty" : "context.elements.too_many"]
      end
    end
  end

  it "uses text object limits in Context and checks block IDs" do
    DisplayUI::Blocks::Context.new(elements: {DisplayUI.plain("界" * 3000), DisplayUI.mrkdwn("界" * 3000)}).validate.should be_empty
    error = expect_raises(DisplayUI::ValidationError) { DisplayUI::Blocks::Context.new(elements: [DisplayUI.plain("Context")], block_id: "x" * 256) }
    error.issues.map(&.code).should eq ["context.block_id.too_long"]
  end

  it "validates image block field lengths without applying its alt limit to elements" do
    DisplayUI::Blocks::Image.new(image_url: "界" * 3000, alt_text: "界" * 2000, title: DisplayUI.plain("界" * 2000), block_id: "界" * 255).validate.should be_empty
    error = expect_raises(DisplayUI::ValidationError) do
      DisplayUI::Blocks::Image.new(image_url: "界" * 3001, alt_text: "界" * 2001, title: DisplayUI.plain("界" * 2001), block_id: "界" * 256)
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"image.image_url.too_long", "image_url"}, {"image.alt_text.too_long", "alt_text"},
      {"image.block_id.too_long", "block_id"}, {"image.title.too_long", "title.text"},
    ]
    DisplayUI::BlockElements::Image.new(image_url: "界" * 3000, alt_text: "界" * 2001).validate.should be_empty
    error = expect_raises(DisplayUI::ValidationError) { DisplayUI::BlockElements::Image.new(image_url: "界" * 3001, alt_text: "Image") }
    error.issues.map(&.code).should eq ["image.image_url.too_long"]
  end

  it "requires nonempty accessible summaries and source values" do
    {DisplayUI::Blocks::Image, DisplayUI::BlockElements::Image}.each do |type|
      error = expect_raises(DisplayUI::ValidationError) { type.new(image_url: "", alt_text: "") }
      error.issues.map(&.code).should eq %w[image.alt_text.empty image.image_url.empty]
      error = expect_raises(DisplayUI::ValidationError) { type.new(slack_file: DisplayUI::CompositionObjects::SlackFile.new(id: "F123"), alt_text: "") }
      error.issues.map(&.code).should eq ["image.alt_text.empty"]
    end
    expect_raises(DisplayUI::ValidationError) { DisplayUI::CompositionObjects::SlackFile.new(id: "") }.issues.map(&.code).should eq ["slack_file.id.empty"]
    expect_raises(DisplayUI::ValidationError) { DisplayUI::CompositionObjects::SlackFile.new(url: "") }.issues.map(&.code).should eq ["slack_file.url.empty"]
  end

  it "supports every display parent and surface through constructors and builders" do
    image = DisplayUI::BlockElements::Image.new(image_url: "https://example.test/a.png", alt_text: "Diagram")
    section = DisplayUI::Blocks::Section.new(text: DisplayUI.plain("Section"), fields: {DisplayUI.mrkdwn("Field")}, accessory: image)
    blocks = {DisplayUI::Blocks::Header.new(text: DisplayUI.plain("Heading")), DisplayUI::Blocks::Context.new(elements: {image, DisplayUI.mrkdwn("Context")}), DisplayUI::Blocks::Image.new(slack_file: DisplayUI::CompositionObjects::SlackFile.new(id: "F123"), alt_text: "Diagram"), section}
    surfaces = {
      DisplayUI::Message.new(fallback_text: "Diagram overview", blocks: blocks),
      DisplayUI::DisplayModal.new(title: DisplayUI.plain("Display"), blocks: blocks),
      DisplayUI::FormModal.new(title: DisplayUI.plain("Form"), submit: DisplayUI.plain("Save"), blocks: blocks),
      DisplayUI::Home.new(blocks: blocks),
    }
    surfaces.each { |surface| JSON.parse(surface.to_json)["blocks"].should eq JSON.parse(blocks.to_json) }
    builders = {DisplayUI::MessageBuilder.new(fallback_text: "Diagram overview"), DisplayUI::DisplayModalBuilder.new(title: DisplayUI.plain("Display")), DisplayUI::FormModalBuilder.new(title: DisplayUI.plain("Form"), submit: DisplayUI.plain("Save")), DisplayUI::HomeBuilder.new}
    builders.each do |builder|
      builder.header(text: DisplayUI.plain("Heading"), level: 4)
      builder.context(elements: {image, DisplayUI.mrkdwn("Context")})
      builder.image(image_url: "https://example.test/a.png", alt_text: "Diagram")
      builder.image(slack_file: DisplayUI::CompositionObjects::SlackFile.new(url: "https://files.slack.com/a"), alt_text: "Diagram")
      builder.section(text: DisplayUI.plain("Section"), accessory: image)
      builder.add_all(blocks)
      builder.build.blocks.size.should eq 9
    end
  end

  it "preserves Context snapshots through each surface after nested and builder mutations" do
    elements = [DisplayUI.plain("Original")]
    context = DisplayUI::Blocks::Context.new(elements: elements)
    blocks = [context]
    builders = {DisplayUI::MessageBuilder.new(fallback_text: "Original"), DisplayUI::DisplayModalBuilder.new(title: DisplayUI.plain("Display")), DisplayUI::FormModalBuilder.new(title: DisplayUI.plain("Form"), submit: DisplayUI.plain("Save")), DisplayUI::HomeBuilder.new}
    builders.each do |builder|
      builder.add_all(blocks)
      snapshot = builder.build
      before = snapshot.to_json
      elements.clear
      context.elements.clear
      snapshot.blocks.each { |block| block.elements.clear if block.is_a?(DisplayUI::Blocks::Context) }
      snapshot.blocks.clear
      builder.divider
      snapshot.to_json.should eq before
    end
    direct = DisplayUI::Home.new(blocks: blocks)
    blocks.clear
    direct.blocks.size.should eq 1
  end
end

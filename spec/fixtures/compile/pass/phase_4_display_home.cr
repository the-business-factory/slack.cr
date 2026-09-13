require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

class HomeBlocks
  include Enumerable(UI::Blocks::Input | UI::Blocks::Context)

  def each(&) : Nil
    yield UI::Blocks::Context.new(elements: [UI.plain("Context")])
  end
end

class ContextElements
  include Enumerable(UI::CompositionObjects::Text | UI::BlockElements::Image)

  def each(&) : Nil
    yield UI.plain("Context")
  end
end

struct ProjectHeading
  def render : UI::Blocks::Header
    UI::Blocks::Header.new(text: UI.plain("Projects"), level: 2)
  end

  def render_into(builder : UI::HomeBuilder) : Nil
    builder.add(render)
  end
end

file = UI::CompositionObjects::SlackFile.new(id: "F123")
file_url = UI::CompositionObjects::SlackFile.new(url: "https://files.slack.com/a")
image = UI::BlockElements::Image.new(slack_file: file, alt_text: "Thumbnail")
UI::BlockElements::Image.new(slack_file: file_url, alt_text: "Thumbnail").to_json
UI::BlockElements::Image.new(image_url: "https://example.test/a.png", alt_text: "Thumbnail").to_json
image_block = UI::Blocks::Image.new(slack_file: file, alt_text: "Diagram", title: UI.plain("Diagram"))
context = UI::Blocks::Context.new(elements: {UI.plain("Context"), UI.mrkdwn("*Ready*"), image})
UI::Blocks::Context.new(elements: [UI.plain("Context"), image]).to_json
UI::Blocks::Context.new(elements: [image]).to_json
UI::Blocks::Context.new(elements: ContextElements.new).to_json
header = ProjectHeading.new.render
input = UI::Blocks::Input.new(label: UI.plain("Note"), element: UI::BlockElements::PlainTextInput.new)
blocks = {header, context, image_block}
UI::Home.new(blocks: HomeBlocks.new).to_json
UI::Home.new(blocks: [input]).to_json
UI::Home.new(blocks: [input, context]).to_json
UI::Home.new(blocks: {input, header}).to_json
normalized = [header, input] of UI::HomeBlock
UI::Home.new(blocks: normalized).to_json
UI::Message.new(fallback_text: "Projects", blocks: blocks).to_json
UI::DisplayModal.new(title: UI.plain("Projects"), blocks: blocks).to_json
UI::FormModal.new(title: UI.plain("Projects"), submit: UI.plain("Save"), blocks: {input, context}).to_json
builders = {UI::HomeBuilder.new, UI::MessageBuilder.new(fallback_text: "Projects"), UI::DisplayModalBuilder.new(title: UI.plain("Projects")), UI::FormModalBuilder.new(title: UI.plain("Projects"), submit: UI.plain("Save"))}
builders.each do |builder|
  builder.header(text: UI.plain("Projects"), level: 4)
  builder.context(elements: ContextElements.new)
  builder.image(image_url: "https://example.test/a.png", alt_text: "Diagram", title: UI.plain("Diagram"))
  builder.image(slack_file: file_url, alt_text: "Diagram")
  builder.add_all(blocks)
  optional : UI::Blocks::Section::Accessory? = image
  builder.section(text: UI.plain("Details"), accessory: optional)
  builder.build.to_json
end
UI.home(private_metadata: "", callback_id: "projects", external_id: "projects-U123") do |builder|
  builder.add_all(HomeBlocks.new)
  builder.add_all([input])
  builder.add_all([input, context])
  builder.add_all({input, header})
  builder.add_all(normalized)
  ProjectHeading.new.render_into(builder)
  builder.input(label: UI.plain("Note"), element: UI::BlockElements::PlainTextInput.new)
end.to_json

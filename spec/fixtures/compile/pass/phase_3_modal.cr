require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

class ModalBlocks
  include Enumerable(UI::Blocks::Input | UI::Blocks::Divider)

  def each(&) : Nil
    yield UI::Blocks::Divider.new
  end
end

class DisplayBlocks
  include Enumerable(UI::Blocks::Section | UI::Blocks::Divider)

  def each(&) : Nil
    yield UI::Blocks::Divider.new
  end
end

input = UI::Blocks::Input.new(label: UI.plain("Text"), element: UI::BlockElements::PlainTextInput.new)
divider = UI::Blocks::Divider.new
section = UI::Blocks::Section.new(text: UI.mrkdwn("*Details*"))
form = UI::FormModalBuilder.new(title: UI.plain("Form"), submit: UI.plain("Send"))
form.add_all([input])
form.add_all([input, divider])
form.add_all({input, section})
form.add_all(ModalBlocks.new)
form.actions(elements: [UI::BlockElements::Button.new(text: UI.plain("Open"))])
form.input(label: UI.plain("Text"), element: UI::BlockElements::PlainTextInput.new)
form.build.to_json
UI::FormModal.new(title: UI.plain("Form"), submit: UI.plain("Send"), blocks: ModalBlocks.new).to_json
UI::FormModal.new(title: UI.plain("Form"), submit: UI.plain("Send"), blocks: {input, divider}).to_json
UI::FormModal.new(title: UI.plain("Form"), submit: UI.plain("Send"), blocks: [input]).to_json
UI::DisplayModal.new(title: UI.plain("Display"), blocks: DisplayBlocks.new).to_json
UI::DisplayModal.new(title: UI.plain("Display"), blocks: {section, divider}).to_json
UI.display_modal(title: UI.plain("Display")) do |builder|
  builder.add_all(DisplayBlocks.new)
  builder.add_all({section, divider})
  builder.add_all([section])
end.to_json
UI.form_modal(title: UI.plain("Form"), submit: UI.plain("Send")) { |builder| builder.add(input) }.to_json

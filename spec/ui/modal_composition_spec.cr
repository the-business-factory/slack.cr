require "../../spec_helper"

module ModalCompositionSpec
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

  describe "modal composition" do
    it "executes typed collections and reusable components" do
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
      payload = JSON.parse(form.build.to_json)
      payload["blocks"].as_a.map(&.["type"].as_s).should eq %w[input input divider input section divider actions input]
      payload["blocks"][4]["text"]["text"].should eq "*Details*"
      UI::FormModal.new(title: UI.plain("Form"), submit: UI.plain("Send"), blocks: ModalBlocks.new).blocks.map(&.type).should eq ["divider"]
      UI::FormModal.new(title: UI.plain("Form"), submit: UI.plain("Send"), blocks: {input, divider}).to_json
      UI::FormModal.new(title: UI.plain("Form"), submit: UI.plain("Send"), blocks: [input]).to_json
      UI::DisplayModal.new(title: UI.plain("Display"), blocks: DisplayBlocks.new).blocks.map(&.type).should eq ["divider"]
      UI::DisplayModal.new(title: UI.plain("Display"), blocks: {section, divider}).to_json
      UI.display_modal(title: UI.plain("Display")) do |builder|
        builder.add_all(DisplayBlocks.new)
        builder.add_all({section, divider})
        builder.add_all([section])
      end.blocks.map(&.type).should eq %w[divider section divider section]
      UI.form_modal(title: UI.plain("Form"), submit: UI.plain("Send")) { |builder| builder.add(input) }.to_json
    end
  end
end

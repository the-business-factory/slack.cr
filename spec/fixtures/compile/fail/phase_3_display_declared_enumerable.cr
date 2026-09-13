require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

class BroadBlocks
  include Enumerable(UI::Blocks::Divider | UI::Blocks::Input)

  def each(&) : Nil
    yield UI::Blocks::Divider.new
  end
end

UI::DisplayModal.new(title: UI.plain("Display"), blocks: BroadBlocks.new)

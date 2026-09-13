require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

class BroadBlocks
  include Enumerable(UI::Blocks::Divider | UI::Blocks::Input)

  def each(&) : Nil
    yield UI::Blocks::Divider.new
  end
end

UI::DisplayModalBuilder.new(title: UI.plain("Display")).add_all(BroadBlocks.new)

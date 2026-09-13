require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

class BroadBlocks
  include Enumerable(UI::Blocks::Divider | String)

  def each(&) : Nil
    yield UI::Blocks::Divider.new
  end
end

UI::FormModal.new(title: UI.plain("Form"), submit: UI.plain("Send"), blocks: BroadBlocks.new)

require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

class Broad
  include Enumerable(UI::Blocks::Header | String)

  def each(&) : Nil
    yield UI::Blocks::Header.new(text: UI.plain("Heading"))
  end
end

UI::Home.new(blocks: Broad.new)

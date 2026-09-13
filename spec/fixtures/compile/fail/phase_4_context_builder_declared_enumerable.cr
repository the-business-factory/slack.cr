require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

class Broad
  include Enumerable(UI::CompositionObjects::PlainText | String)

  def each(&) : Nil
    yield UI.plain("Context")
  end
end

UI.home(&.context(elements: Broad.new))

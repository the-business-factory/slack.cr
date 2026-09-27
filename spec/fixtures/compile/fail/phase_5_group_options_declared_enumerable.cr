require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked

class BroadItems
  include Enumerable(UI::CompositionObjects::Option | String)

  def each(&) : Nil
    yield UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
  end
end

UI::CompositionObjects::OptionGroup.new(label: UI.plain("Group"), options: BroadItems.new)

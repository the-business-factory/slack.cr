require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked

class BroadItems
  include Enumerable(UI::CompositionObjects::Option | UI::CompositionObjects::OptionGroup)

  def each(&) : Nil
    yield UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
  end
end

UI::BlockElements::StaticSelect.new(options: BroadItems.new)

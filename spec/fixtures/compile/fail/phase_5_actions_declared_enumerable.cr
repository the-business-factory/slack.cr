require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked

class BroadItems
  include Enumerable(UI::BlockElements::StaticSelect | UI::CompositionObjects::Option)

  def each(&) : Nil
    yield UI::BlockElements::StaticSelect.new(options: {UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")})
  end
end

UI::Blocks::Actions.new(elements: BroadItems.new)

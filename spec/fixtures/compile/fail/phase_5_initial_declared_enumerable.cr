require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked
option = UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")

class BroadItems
  include Enumerable(UI::CompositionObjects::Option | String)

  def each(&) : Nil
    yield UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
  end
end

UI::BlockElements::MultiStaticSelect.new(options: {option}, initial_options: BroadItems.new)

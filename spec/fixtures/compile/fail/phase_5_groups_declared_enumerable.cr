require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked

class BroadItems
  include Enumerable(UI::CompositionObjects::OptionGroup | String)

  def each(&) : Nil
    yield UI::CompositionObjects::OptionGroup.new(label: UI.plain("Group"), options: {UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")})
  end
end

UI::BlockElements::StaticSelect.new(option_groups: BroadItems.new)

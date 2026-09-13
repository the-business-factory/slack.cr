require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked

class BroadItems
  include Enumerable(UI::BlockElements::MultiStaticSelect | UI::CompositionObjects::Option)

  def each(&) : Nil
    yield UI::BlockElements::MultiStaticSelect.new(options: {UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")})
  end
end

UI::HomeBuilder.new.actions(BroadItems.new)

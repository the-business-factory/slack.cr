require "../../../src/slack/ui"

module StaticSelectFixture
  alias UI = Slack::UI::Checked

  def self.option(value : String = "red", text : String = "Red") : UI::CompositionObjects::Option
    UI::CompositionObjects::Option.new(text: UI.plain(text, emoji: false), value: value, description: UI.plain("Team color"))
  end

  def self.single : UI::BlockElements::StaticSelect
    UI::BlockElements::StaticSelect.new(options: {option, option("blue", "Blue")},
      action_id: "color", placeholder: UI.plain("Choose a color"), initial_option: option,
      focus_on_load: false, confirm: UI::CompositionObjects::Confirmation.new(
      title: UI.plain("Change color?"), text: UI.plain("Apply this color."), confirm: UI.plain("Apply"), deny: UI.plain("Cancel")))
  end

  def self.multi : UI::BlockElements::MultiStaticSelect
    group = UI::CompositionObjects::OptionGroup.new(label: UI.plain("Colors"), options: {option, option("blue", "Blue")})
    UI::BlockElements::MultiStaticSelect.new(option_groups: {group}, action_id: "colors",
      placeholder: UI.plain("Choose colors"), initial_options: {option}, max_selected_items: 2,
      focus_on_load: true, confirm: UI::CompositionObjects::Confirmation.new(
      title: UI.plain("Change colors?"), text: UI.plain("Apply these colors."), confirm: UI.plain("Apply"), deny: UI.plain("Cancel")))
  end
end

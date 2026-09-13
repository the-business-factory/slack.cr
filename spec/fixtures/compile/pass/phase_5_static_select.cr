require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

class MenuOptions
  include Enumerable(UI::CompositionObjects::Option)

  def each(&) : Nil
    yield UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
  end
end

class MenuGroups
  include Enumerable(UI::CompositionObjects::OptionGroup)

  def each(&) : Nil
    yield UI::CompositionObjects::OptionGroup.new(label: UI.plain("Group"), options: MenuOptions.new)
  end
end

class MenuActions
  include Enumerable(UI::BlockElements::StaticSelect | UI::BlockElements::MultiStaticSelect)

  def each(&) : Nil
    yield UI::BlockElements::StaticSelect.new(options: MenuOptions.new)
  end
end

struct ColorPicker
  def render : UI::Blocks::Section
    UI::Blocks::Section.new(text: UI.plain("Colors"), accessory: UI::BlockElements::StaticSelect.new(options: MenuOptions.new))
  end

  def render_into(builder : UI::MessageBuilder) : Nil
    builder.add(render)
  end
end

option = UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
group = UI::CompositionObjects::OptionGroup.new(label: UI.plain("Group"), options: [option])
UI::CompositionObjects::OptionGroup.new(label: UI.plain("Group"), options: {option}).to_json
single = UI::BlockElements::StaticSelect.new(options: {option}, initial_option: option)
multi = UI::BlockElements::MultiStaticSelect.new(option_groups: [group], initial_options: MenuOptions.new, max_selected_items: 1)
UI::BlockElements::StaticSelect.new(option_groups: MenuGroups.new, initial_option: option).to_json
UI::BlockElements::StaticSelect.new(options: MenuOptions.new).to_json
UI::BlockElements::MultiStaticSelect.new(options: [option], initial_options: {option}).to_json
UI::BlockElements::MultiStaticSelect.new(options: MenuOptions.new).to_json
UI::BlockElements::MultiStaticSelect.new(option_groups: {group}, initial_options: [option]).to_json
UI::BlockElements::MultiStaticSelect.new(option_groups: MenuGroups.new).to_json
UI::Blocks::Actions.new(elements: MenuActions.new).to_json
UI::Blocks::Actions.new(elements: [single]).to_json
UI::Blocks::Actions.new(elements: [single, multi]).to_json
UI::Blocks::Actions.new(elements: {single, multi}).to_json
normalized = [single, multi] of UI::Blocks::Actions::Element
UI::Blocks::Actions.new(elements: normalized).to_json
optional : UI::Blocks::Section::Accessory? = multi
UI::Blocks::Section.new(text: UI.plain("Colors"), accessory: optional).to_json
input = UI::Blocks::Input.new(label: UI.plain("Colors"), element: multi)
UI::Home.new(blocks: {input, ColorPicker.new.render}).to_json
UI::FormModal.new(title: UI.plain("Colors"), submit: UI.plain("Save"), blocks: [input]).to_json
{UI::MessageBuilder.new(fallback_text: "Colors"), UI::HomeBuilder.new,
 UI::FormModalBuilder.new(title: UI.plain("Colors"), submit: UI.plain("Save")),
 UI::DisplayModalBuilder.new(title: UI.plain("Colors"))}.each do |builder|
  builder.actions(MenuActions.new)
  builder.actions(normalized)
  builder.section(text: UI.plain("Colors"), accessory: optional)
  builder.add_all({ColorPicker.new.render})
  builder.build.to_json
end
{UI::HomeBuilder.new, UI::FormModalBuilder.new(title: UI.plain("Colors"), submit: UI.plain("Save"))}.each do |builder|
  builder.input(label: UI.plain("One"), element: single)
  builder.input(label: UI.plain("Many"), element: multi)
  builder.build.to_json
end
builder = UI::MessageBuilder.new(fallback_text: "Colors")
ColorPicker.new.render_into(builder)
puts builder.build.to_json

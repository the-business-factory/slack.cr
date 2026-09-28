require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

label = UI.plain("Input")
input = UI::Blocks::Input.new(label: label, element: UI::BlockElements::PlainTextInput.new)
section = UI::Blocks::Section.new(text: label)
UI::Blocks::Section.new(fields: {label})
UI::FormModal.new(title: label, submit: UI.plain("Save"), blocks: [input])
UI::DisplayModal.new(title: label, blocks: [section])
option = UI::CompositionObjects::Option.new(text: label, value: "one")
group = UI::CompositionObjects::OptionGroup.new(label: label, options: {option})
UI::BlockElements::StaticSelect.new(options: {option})
UI::BlockElements::StaticSelect.new(option_groups: {group})
overflow_option = UI::CompositionObjects::OverflowOption.new(text: label, value: "details", url: "https://example.com")
overflow = UI::BlockElements::Overflow.new(options: {overflow_option})
UI::Blocks::Section.new(text: label, accessory: overflow)
UI::Blocks::Actions.new(elements: {overflow})
datetime = UI::BlockElements::DatetimePicker.new(action_id: "start")
UI::Blocks::Actions.new(elements: {datetime})
UI::Blocks::Input.new(label: label, element: datetime)
UI::Message.new(fallback_text: "File", blocks: [UI::Blocks::File.new(external_id: "ABCD1"), section])

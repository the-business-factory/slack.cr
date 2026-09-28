require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

label = UI.plain("Input")
input = UI::Blocks::Input.new(label: label, element: UI::BlockElements::PlainTextInput.new)
section = UI::Blocks::Section.new(text: label)
UI::Blocks::Section.new(fields: {label})
UI::FormModal.new(title: label, submit: UI.plain("Save"), blocks: [input])
UI::DisplayModal.new(title: label, blocks: [section])
UI::DisplayModal.new(title: label, blocks: [UI::Blocks::Alert.new(label), section])
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
UI.home(&.table({ {UI::Table::RawText.new("Open")} }))
UI.home(&.data_visualization("Tickets", UI::DataVisualization::PieChart.new({UI::DataVisualization::Segment.new("Open", 1)})))
card = UI::Blocks::Card.new(title: label)
UI.home(&.carousel({card}))
UI::DisplayModal.new(title: label, blocks: [card, section])
UI::Message.new(fallback_text: "File", blocks: [UI::Blocks::File.new(external_id: "ABCD1"), section])
trash = UI::BlockElements::IconButton.new(UI::BlockElements::IconButtonIcon::Trash, text: UI.plain("Delete"))
UI::Message.new(fallback_text: "Answer", blocks: [UI::Blocks::ContextActions.new(elements: {trash}), section])
rich_cell = UI::Blocks::RichText.new(elements: {UI::RichText::Section.new(elements: {UI::RichText::Text.new("T-1")})})
UI.home(&.data_table(caption: "Queue", header: {UI::Table::RawText.new("Ticket")}, rows: { {rich_cell} }))
item = UI::RichText::Section.new(elements: {UI::RichText::Text.new("Item")})
UI::Blocks::RichText.new(elements: {UI::RichText::List.new(UI::RichText::ListStyle::Bullet, elements: {item})})
UI.form_modal(title: label, submit: UI.plain("Save")) do |builder|
  builder.input(label: label, element: UI::BlockElements::NumberInput.new(is_decimal_allowed: false))
end
UI.home do |builder|
  builder.input(label: label, element: UI::BlockElements::RichTextInput.new(action_id: "summary"))
end

require "./spec_helper"
require "./support/compile_contracts"

describe "Block Kit construction diagnostics" do
  root = File.expand_path("..", __DIR__)
  positive_checked = false

  # Lazy prerequisite also runs when a single diagnostic is selected by line/name.
  before_each do
    unless positive_checked
      CompileContracts.assert_pass(CompileContracts.compile(root, "spec/fixtures/compile/pass/diagnostics.cr"))
      positive_checked = true
    end
  end

  {
    "overflow_static_option" => ["OverflowOption", "CompositionObjects::Option"],
    "overflow_input"         => ["Input.new", "argument 'element'", "Overflow"],
    "input_label"            => ["Input.new", "argument 'label'", "PlainText", "Mrkdwn"],
    "section_content"        => ["Section.new", "text :", "fields :"],
    "form_submit"            => ["FormModal.new", "missing argument: submit", "submit :"],
    "display_input"          => ["DisplayModal", "Input", "FormModal with submit"],
    "select_sources"         => ["StaticSelect.new", "options :", "option_groups :"],
    "datetime_accessory"     => ["Section.new", "accessory", "DatetimePicker"],
    "home_file"              => ["Home#append_block", "Blocks::File"],
    "display_file"           => ["DisplayModal rejects File blocks", "messages only"],
    "rich_text_list_item"    => ["RichText::List#append_element", "RichText::Section", "not Slack::UI::Checked::RichText::Text"],
  }.each do |name, fragments|
    it "explains #{name}" do
      result = CompileContracts.compile(root, "spec/fixtures/compile/fail/#{name}.cr")
      fragments.each { |fragment| CompileContracts.assert_fail(result, fragment) }
    end
  end
end

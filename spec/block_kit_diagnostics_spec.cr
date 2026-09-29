require "./spec_helper"
require "./support/compile_contracts"

# One fixture per rule that a single parameter type does not show: a
# diagnostic that the library writes, or a required or exclusive argument
# pair. Placement through a typed append is one mechanism and is covered once.
describe "Block Kit construction and app listener diagnostics" do
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
    "section_content" => ["Section.new", "text :", "fields :"],
    "select_sources"  => ["StaticSelect.new", "options :", "option_groups :"],
    "container_title" => ["Container.new", "title : CompositionObjects::PlainText", "rich_text_title : RichText,"],
    "form_submit"     => ["FormModal.new", "missing argument: submit", "submit :"],
    "display_input"   => ["DisplayModal", "Input", "FormModal with submit"],
    "display_table"   => ["DisplayModal rejects Table blocks", "messages and Home tabs only"],
    "message_alert"   => ["Messages and Home tabs reject Alert blocks", "modals only"],
    "home_file"       => ["Home#append_block", "Blocks::File"],
  }.each do |name, fragments|
    it "explains #{name}" do
      result = CompileContracts.compile(root, "spec/fixtures/compile/fail/#{name}.cr")
      CompileContracts.assert_fail(result, fragments)
    end
  end
end

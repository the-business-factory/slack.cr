require "../spec_helper"

module ContainerBlockSpec
  alias UI = Slack::UI
  alias RT = UI::RichText

  def self.section(text : String, block_id : String? = nil) : UI::Blocks::Section
    UI::Blocks::Section.new(text: UI.mrkdwn(text), block_id: block_id)
  end

  def self.rich_title(text : String) : UI::Blocks::RichText
    UI::Blocks::RichText.new(elements: {RT::Section.new(elements: {RT::Text.new(text, style: RT::TextStyle.new(bold: true))})})
  end

  def self.focused_input(action_id : String, block_id : String? = nil) : UI::Blocks::Input
    UI::Blocks::Input.new(label: UI.plain("Note"), block_id: block_id,
      element: UI::BlockElements::PlainTextInput.new(action_id: action_id, focus_on_load: true))
  end

  describe UI::Blocks::Container do
    it "serializes titled containers with display, file, table, and input children in a message" do
      button = UI::BlockElements::Button.new(text: UI.plain("Confirm All"), action_id: "bulk_confirm", style: UI::BlockElements::ButtonStyle::Primary)
      review = UI::Blocks::Container.new(
        title: UI.plain("Bulk update: 2 records selected"),
        subtitle: UI.mrkdwn("Review *all* changes"),
        width: UI::Blocks::Container::Width::Wide,
        icon: UI::BlockElements::Image.new(alt_text: "Records", image_url: "https://example.com/records.png"),
        is_collapsible: true, default_collapsed: false, has_header_divider: false,
        block_id: "bulk.update",
        child_blocks: [
          UI::Blocks::Header.new(text: UI.plain("Changes")),
          section("*DCW-1024*\nStatus: Open → Closed", block_id: "record-row-1"),
          UI::Blocks::Divider.new,
          UI::Blocks::Context.new(elements: {UI.mrkdwn("2 records will be updated")}),
          UI::Blocks::Image.new(alt_text: "Chart", image_url: "https://example.com/chart.png"),
          UI::Blocks::Input.new(label: UI.plain("Reason"), block_id: "reason", element: UI::BlockElements::PlainTextInput.new(action_id: "reason")),
          UI::Blocks::Actions.new(elements: {button}, block_id: "bulk-actions"),
        ]
      )
      mention = UI::Blocks::RichText.new(elements: {RT::Section.new(elements: {RT::User.new("U-SYNTHETIC")})})
      attachments = UI::Blocks::Container.new(
        title: UI.plain("Ignored when rich_text_title is present"),
        rich_text_title: rich_title("Attachments"),
        width: UI::Blocks::Container::Width::Full,
        child_blocks: {
          UI::Blocks::File.new(external_id: "ABCD1"), mention,
          UI::Blocks::Table.new(rows: { {UI::Table::RawText.new("Open"), UI::Table::RawNumber.new(4, "4")} }),
        }
      )
      message = UI::Message.new(fallback_text: "Bulk update: 2 records selected", blocks: [review, attachments])

      JSON.parse(message.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/container_message.json"))
    end

    it "places a container with only a rich text title on Home" do
      container = UI::Blocks::Container.new(rich_text_title: rich_title("Queue"), child_blocks: {section("3 open")},
        width: UI::Blocks::Container::Width::Narrow)
      home = UI.home(&.add(container))

      JSON.parse(home.to_json)["blocks"].should eq JSON.parse(<<-JSON)
        [{"type":"container","width":"narrow",
          "rich_text_title":{"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"Queue","style":{"bold":true}}]}]},
          "child_blocks":[{"type":"section","text":{"type":"mrkdwn","text":"3 open"}}]}]
        JSON
    end

    it "owns a copy of its child blocks" do
      children = [section("First")] of UI::Blocks::Container::Child
      container = UI::Blocks::Container.new(title: UI.plain("Queue"), child_blocks: children)
      children << UI::Blocks::Divider.new
      container.child_blocks << UI::Blocks::Divider.new

      container.child_blocks.size.should eq 1
      JSON.parse(container.to_json)["child_blocks"].as_a.size.should eq 1
    end

    it "accepts Slack's documented maximums" do
      container = UI::Blocks::Container.new(
        title: UI.plain("界" * 150), subtitle: UI.plain("界" * 150), block_id: "界" * 255,
        icon: UI::BlockElements::Image.new(alt_text: "界" * 2000, image_url: "https://example.com/" + "a" * 2980),
        child_blocks: Array.new(10) { UI::Blocks::Divider.new }
      )

      container.child_blocks.size.should eq 10
    end

    it "rejects values beyond Slack's limits" do
      error = expect_raises(UI::ValidationError) do
        UI::Blocks::Container.new(
          title: UI.plain("界" * 151), subtitle: UI.mrkdwn("界" * 151), block_id: "界" * 256,
          icon: UI::BlockElements::Image.new(alt_text: "界" * 2001, image_url: "https://example.com/icon.png"),
          child_blocks: Array.new(11) { UI::Blocks::Divider.new }
        )
      end
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"container.title.too_long", "title.text"},
        {"container.subtitle.too_long", "subtitle.text"},
        {"container.icon.alt_text.too_long", "icon.alt_text"},
        {"container.child_blocks.too_many", "child_blocks"},
        {"container.block_id.too_long", "block_id"},
      ]
    end

    it "rejects a container without child blocks as library policy" do
      error = expect_raises(UI::ValidationError) do
        UI::Blocks::Container.new(title: UI.plain("Empty"), child_blocks: [] of UI::Blocks::Container::Child)
      end
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"container.child_blocks.empty", "child_blocks"}]
    end
  end

  describe "containers in surfaces" do
    it "checks block IDs across top-level blocks and container children" do
      container = UI::Blocks::Container.new(title: UI.plain("Queue"), block_id: "queue",
        child_blocks: {section("One", block_id: "row"), section("Two", block_id: "row"), section("Three", block_id: "top")})
      error = expect_raises(UI::ValidationError) do
        UI::Message.new(fallback_text: "Queue", blocks: [section("Top", block_id: "top"), container, section("Queue", block_id: "queue")])
      end
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"message.block_id.duplicate", "blocks[1].child_blocks[1].block_id"},
        {"message.block_id.duplicate", "blocks[1].child_blocks[2].block_id"},
        {"message.block_id.duplicate", "blocks[2].block_id"},
      ]
    end

    it "keeps one focused element per Home view across container children" do
      container = UI::Blocks::Container.new(title: UI.plain("Notes"), child_blocks: {focused_input("inner")})
      error = expect_raises(UI::ValidationError) do
        UI.home do |builder|
          builder.add(focused_input("outer"))
          builder.add(container)
        end
      end
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"home.focus_on_load.duplicate", "blocks[1].child_blocks[0].element.focus_on_load"},
      ]
      UI.home(&.add(container)).validate.should be_empty
    end

    it "rejects Home container children that Slack documents only for messages" do
      picker = UI::BlockElements::DatetimePicker.new(action_id: "when")
      container = UI::Blocks::Container.new(title: UI.plain("Mixed"), child_blocks: {
        UI::Blocks::File.new(external_id: "ABCD1"),
        UI::Blocks::Actions.new(elements: {picker}),
        UI::Blocks::Input.new(label: UI.plain("When"), element: picker),
      })

      error = expect_raises(UI::ValidationError) { UI::Home.new(blocks: {container}) }
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"home.file.unsupported_surface", "blocks[0].child_blocks[0]"},
        {"home.datetimepicker.unsupported_surface", "blocks[0].child_blocks[1].elements[0]"},
        {"home.datetimepicker.unsupported_surface", "blocks[0].child_blocks[2].element"},
      ]
    end

    it "rejects workflow buttons in Home container children and keeps them in messages" do
      workflow = UI::CompositionObjects::Workflow.new(trigger: UI::CompositionObjects::WorkflowTrigger.new(url: "https://slack.com/shortcuts/Ft0SYNTHETIC/run"))
      run = UI::BlockElements::WorkflowButton.new(text: UI.plain("Run"), action_id: "run", workflow: workflow)
      container = UI::Blocks::Container.new(title: UI.plain("Runbook"), child_blocks: {
        UI::Blocks::Section.new(text: UI.plain("Restart"), accessory: run),
        UI::Blocks::Actions.new(elements: {run}),
      })

      error = expect_raises(UI::ValidationError) { UI::Home.new(blocks: {container}) }
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"home.workflow_button.unsupported_surface", "blocks[0].child_blocks[0].accessory"},
        {"home.workflow_button.unsupported_surface", "blocks[0].child_blocks[1].elements[0]"},
      ]
      UI::Message.new(fallback_text: "Runbook", blocks: {container}).validate.should be_empty
    end

    it "rejects response_url_enabled on a message Input inside a container" do
      target = UI::BlockElements::ConversationsSelect.new(action_id: "target", response_url_enabled: true)
      container = UI::Blocks::Container.new(title: UI.plain("Share"),
        child_blocks: {UI::Blocks::Input.new(label: UI.plain("Target"), element: target)})

      error = expect_raises(UI::ValidationError) { UI::Message.new(fallback_text: "Share", blocks: {container}) }
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"conversations_select.response_url_enabled.unsupported_placement", "blocks[0].child_blocks[0].element.response_url_enabled"},
      ]
    end
  end
end

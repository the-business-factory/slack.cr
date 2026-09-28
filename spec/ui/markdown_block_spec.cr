require "../spec_helper"

module MarkdownBlockSpec
  alias UI = Slack::UI

  describe UI::Blocks::Markdown do
    it "serializes standard markdown text in a message" do
      summary = "## Release 4.2\n\n**Deployed** to _production_.\n\n- [x] migrations\n- [ ] cache warmup\n\n" \
                "```sh\nbin/deploy --env production\n```"
      message = UI.message(fallback_text: "Deploy summary for release 4.2") do |builder|
        builder.markdown(summary)
        builder.divider
        builder.add(UI::Blocks::Markdown.new("See the [runbook](https://docs.example.test/runbook)."))
      end

      JSON.parse(message.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/markdown_message.json"))
    end

    it "requires text and limits one block to 12,000 characters" do
      UI::Blocks::Markdown.new("界" * 12_000).text.size.should eq 12_000

      {"" => "markdown.text.empty", "界" * 12_001 => "markdown.text.too_long"}.each do |text, code|
        error = expect_raises(UI::ValidationError) { UI::Blocks::Markdown.new(text) }
        error.issues.map { |issue| {issue.code, issue.path} }.should eq [{code, "text"}]
      end
    end

    it "limits the text of all markdown blocks in one message to 12,000 characters" do
      within = {UI::Blocks::Markdown.new("a" * 6_000), UI::Blocks::Divider.new, UI::Blocks::Markdown.new("b" * 6_000)}
      UI::Message.new(fallback_text: "Report", blocks: within).blocks.size.should eq 3

      error = expect_raises(UI::ValidationError) do
        UI.message(fallback_text: "Report") do |builder|
          builder.markdown("a" * 6_000)
          builder.section(UI.mrkdwn("b" * 3_000))
          builder.markdown("c" * 6_001)
        end
      end
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"message.markdown.too_long", "blocks"}]
    end
  end
end

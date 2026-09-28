require "../../spec_helper"

private alias FileUI = Slack::UI::Checked

describe FileUI::Blocks::File do
  it "serializes remote file blocks in a message with and without a block ID" do
    message = FileUI.message(fallback_text: "Quarterly plan shared.") do |builder|
      builder.file(external_id: "ABCD1", block_id: "plan.file")
      builder.add(FileUI::Blocks::File.new(external_id: "ABCD2"))
    end

    JSON.parse(message.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/file_message.json"))
  end

  it "requires an external ID and limits the block ID to 255 characters" do
    FileUI::Blocks::File.new(external_id: "ABCD1", block_id: "界" * 255).block_id.should eq "界" * 255

    error = expect_raises(FileUI::ValidationError) { FileUI::Blocks::File.new(external_id: "", block_id: "界" * 256) }
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"file.external_id.empty", "external_id"},
      {"file.block_id.too_long", "block_id"},
    ]
  end
end

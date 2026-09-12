require "./spec_helper"
require "yaml"

describe "Block Kit support manifest" do
  it "has required metadata, valid statuses, and existing evidence paths" do
    root = File.expand_path("..", __DIR__)
    manifest = YAML.parse(File.read(File.join(root, "documentation/block-kit-support.yml")))
    manifest["checked_on"].to_s.should eq "2026-09-12"
    allowed_statuses = manifest["statuses"].as_a.map(&.as_s)
    allowed_statuses.should eq %w[unsupported partial supported]

    entries = manifest["entries"].as_a
    entries.empty?.should be_false
    entries.each do |entry|
      item = entry.as_h
      %w[wire_type kind documentation_url fields_supported parents surfaces restrictions implementation_status inbound_status evidence_paths].each do |key|
        item.has_key?(key).should be_true, "#{item["wire_type"]}: missing #{key}"
      end
      allowed_statuses.should contain(item["implementation_status"].as_s)
      allowed_statuses.should contain(item["inbound_status"].as_s)
      item["documentation_url"].as_s.starts_with?("https://docs.slack.dev/").should be_true
      item["evidence_paths"].as_a.each do |path|
        File.exists?(File.join(root, path.as_s)).should be_true, "missing evidence path #{path}"
      end
    end
  end
end

require "./spec_helper"
require "yaml"

describe "Block Kit support manifest" do
  it "has required metadata, valid statuses, and existing evidence paths" do
    root = File.expand_path("..", __DIR__)
    manifest = YAML.parse(File.read(File.join(root, "spec/support/block_kit/support.yml")))
    Time.parse(manifest["checked_on"].as_s, "%F", Time::Location::UTC)
    manifest["schema_version"].as_i.should be > 0
    manifest["review_policy"]["cadence"].as_s.empty?.should be_false
    allowed_statuses = manifest["statuses"].as_a.map(&.as_s)
    allowed_statuses.should eq %w[unsupported partial supported]

    rules = manifest["rules"].as_a
    rules.empty?.should be_false
    rules.map(&.["id"].as_s).uniq!.size.should eq rules.size
    rules.each do |rule|
      %w[slack_requirement library_support library_policy].should contain(rule["classification"].as_s)
      Time.parse(rule["reviewed_on"].as_s, "%F", Time::Location::UTC)
      rule["source_url"].as_s.starts_with?("https://docs.slack.dev/").should be_true
      rule["source_section"].as_s.empty?.should be_false
      rule["requirement"].as_s.empty?.should be_false
      rule["evidence_paths"].as_a.empty?.should be_false
      rule["evidence_paths"].as_a.each do |path|
        File.exists?(File.join(root, path.as_s)).should be_true, "missing rule evidence path #{path}"
      end
    end

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

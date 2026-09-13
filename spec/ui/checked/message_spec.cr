require "../../spec_helper"

module Phase2MessageComponents
  struct Summary
    def initialize(@request_id : String)
    end

    def render : Slack::UI::Checked::Blocks::Section
      Slack::UI::Checked::Blocks::Section.new(
        text: Slack::UI::Checked.mrkdwn("*Request #{@request_id}*")
      )
    end
  end

  struct Controls
    def initialize(@request_id : String)
    end

    def render_into(builder : Slack::UI::Checked::MessageBuilder) : Nil
      button = Slack::UI::Checked::BlockElements::Button.new(
        text: Slack::UI::Checked.plain("Approve"),
        action_id: "request.approve",
        value: @request_id
      )
      builder.actions(elements: [button], block_id: "request.controls")
    end
  end
end

describe Slack::UI::Checked::Message do
  it "builds an accessible message with ordinary Crystal components" do
    summary = Phase2MessageComponents::Summary.new("42")
    controls = Phase2MessageComponents::Controls.new("42")

    message = Slack::UI::Checked.message(fallback_text: "Request 42 needs approval.") do |builder|
      builder.add(summary.render)
      builder.divider
      controls.render_into(builder)
    end
    payload = JSON.parse(message.to_json)

    payload["text"].as_s.should eq "Request 42 needs approval."
    payload["blocks"].as_a.map(&.["type"].as_s).should eq %w[section divider actions]
  end

  it "offers a separately named Slack-generated accessibility fallback" do
    message = Slack::UI::Checked.message_with_slack_generated_fallback do |builder|
      builder.section(Slack::UI::Checked.plain("Slack derives this fallback."))
    end
    payload = JSON.parse(message.to_json)

    message.slack_generated_fallback?.should be_true
    payload.as_h.has_key?("text").should be_false
    payload["blocks"].as_a.size.should eq 1
  end

  it "supports direct construction and mixed block collections" do
    section = Slack::UI::Checked::Blocks::Section.new(
      text: Slack::UI::Checked.plain("Summary"),
      block_id: "summary"
    )
    divider = Slack::UI::Checked::Blocks::Divider.new(block_id: "divider")
    blocks = [section, divider]
    message = Slack::UI::Checked::Message.new(
      fallback_text: "Summary",
      blocks: blocks
    )

    message.blocks.size.should eq 2
    JSON.parse(message.to_json)["blocks"].as_a.size.should eq 2
  end

  it "keeps direct and builder snapshots stable" do
    section = Slack::UI::Checked::Blocks::Section.new(
      text: Slack::UI::Checked.plain("First")
    )
    caller_blocks = [section]
    direct = Slack::UI::Checked::Message.new(
      fallback_text: "First",
      blocks: caller_blocks
    )
    direct_json = direct.to_json
    caller_blocks.clear
    direct.blocks.clear
    direct.to_json.should eq direct_json

    builder = Slack::UI::Checked::MessageBuilder.new(fallback_text: "Builder")
    builder.add(section)
    first = builder.build
    first_json = first.to_json
    builder.divider
    first.blocks.clear
    first.to_json.should eq first_json
  end

  it "validates block collection bounds" do
    fifty = Array.new(50) do |index|
      Slack::UI::Checked::Blocks::Divider.new(block_id: "divider-#{index}")
    end
    Slack::UI::Checked::Message.new(fallback_text: "Fifty", blocks: fifty)

    empty_error = expect_raises(Slack::UI::Checked::ValidationError) do
      Slack::UI::Checked::Message.new(
        fallback_text: "Empty",
        blocks: [] of Slack::UI::Checked::MessageBlock
      )
    end
    empty_error.issues.map(&.code).should eq ["message.blocks.empty"]

    count_error = expect_raises(Slack::UI::Checked::ValidationError) do
      Slack::UI::Checked::Message.new(
        fallback_text: "Too many",
        blocks: fifty + [Slack::UI::Checked::Blocks::Divider.new]
      )
    end
    count_error.issues.map(&.code).should contain("message.blocks.too_many")
  end

  it "validates fallback text and message-scoped block IDs" do
    first = Slack::UI::Checked::Blocks::Divider.new(block_id: "same")
    second = Slack::UI::Checked::Blocks::Divider.new(block_id: "same")

    duplicate_error = expect_raises(Slack::UI::Checked::ValidationError) do
      Slack::UI::Checked::Message.new(
        fallback_text: "Duplicates",
        blocks: [first, second]
      )
    end
    duplicate_error.issues.map(&.code).should eq ["message.block_id.duplicate"]
    duplicate_error.issues.map(&.path).should eq ["blocks[1].block_id"]

    fallback_error = expect_raises(Slack::UI::Checked::ValidationError) do
      Slack::UI::Checked::Message.new(fallback_text: "", blocks: [first])
    end
    fallback_error.issues.map(&.code).should eq ["message.fallback_text.empty"]
  end

  it "supports ordinary dynamic builder loops" do
    message = Slack::UI::Checked.message(fallback_text: "Three sections") do |builder|
      3.times do |index|
        builder.section(Slack::UI::Checked.plain("Section #{index}"))
      end
    end

    message.blocks.size.should eq 3
  end
end

require "../../spec_helper"

private alias CheckedBlocks = Slack::UI::Checked::Blocks

describe "checked Block Kit blocks" do
  it "supports every valid Section content shape and all Phase 2 fields" do
    plain = Slack::UI::Checked.plain("Plain")
    markdown = Slack::UI::Checked.mrkdwn("*Markdown*")
    button = Slack::UI::Checked::BlockElements::Button.new(
      text: Slack::UI::Checked.plain("Open"),
      action_id: "open"
    )

    text_only = CheckedBlocks::Section.new(text: markdown)
    fields_only = CheckedBlocks::Section.new(fields: {plain, markdown})
    combined = CheckedBlocks::Section.new(
      text: markdown,
      fields: [plain],
      accessory: button,
      block_id: "summary",
      expand: false
    )

    JSON.parse(text_only.to_json).as_h.keys.should eq ["type", "text"]
    JSON.parse(fields_only.to_json)["fields"].as_a.size.should eq 2
    payload = JSON.parse(combined.to_json)
    payload["accessory"]["type"].as_s.should eq "button"
    payload["block_id"].as_s.should eq "summary"
    payload["expand"].as_bool.should be_false
  end

  it "copies Section field collections and returned arrays" do
    fields = [Slack::UI::Checked.plain("One")]
    section = CheckedBlocks::Section.new(fields: fields)
    before = section.to_json

    fields << Slack::UI::Checked.plain("Two")
    section.fields.try(&.clear)

    section.to_json.should eq before
  end

  it "validates Section field, text, and block ID limits" do
    CheckedBlocks::Section.new(
      text: Slack::UI::Checked.plain("t" * 3000),
      fields: Array.new(10) { Slack::UI::Checked.mrkdwn("f" * 2000) },
      block_id: "✓" * 255
    )

    empty_error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedBlocks::Section.new(fields: [] of Slack::UI::Checked::CompositionObjects::Text)
    end
    empty_error.issues.map(&.code).should eq ["section.fields.empty"]

    count_error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedBlocks::Section.new(
        fields: Array.new(11) { Slack::UI::Checked.plain("Field") }
      )
    end
    count_error.issues.map(&.code).should contain("section.fields.too_many")

    field_error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedBlocks::Section.new(fields: [Slack::UI::Checked.plain("f" * 2001)])
    end
    field_error.issues.map(&.code).should eq ["section.field.text.too_long"]
    field_error.issues.map(&.path).should eq ["fields[0].text"]

    id_error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedBlocks::Section.new(
        text: Slack::UI::Checked.plain("Text"),
        block_id: "✓" * 256
      )
    end
    id_error.issues.map(&.code).should eq ["section.block_id.too_long"]
  end

  it "serializes Actions and accepts arrays, tuples, and custom enumerables" do
    first = Slack::UI::Checked::BlockElements::Button.new(
      text: Slack::UI::Checked.plain("Approve"),
      action_id: "approve"
    )
    second = Slack::UI::Checked::BlockElements::Button.new(
      text: Slack::UI::Checked.plain("Deny"),
      action_id: "deny"
    )
    actions = CheckedBlocks::Actions.new(elements: {first, second}, block_id: "actions")
    payload = JSON.parse(actions.to_json)

    payload["type"].as_s.should eq "actions"
    payload["elements"].as_a.size.should eq 2
    payload["block_id"].as_s.should eq "actions"
  end

  it "copies Actions elements and validates collection limits" do
    source = [checked_button(0)]
    actions = CheckedBlocks::Actions.new(elements: source)
    before = actions.to_json

    source << checked_button(1)
    actions.elements.clear
    actions.to_json.should eq before

    empty_error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedBlocks::Actions.new(elements: [] of Slack::UI::Checked::BlockElements::Button)
    end
    empty_error.issues.map(&.code).should eq ["actions.elements.empty"]

    CheckedBlocks::Actions.new(elements: Array.new(25) { |index| checked_button(index) })
    count_error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedBlocks::Actions.new(elements: Array.new(26) { |index| checked_button(index) })
    end
    count_error.issues.map(&.code).should contain("actions.elements.too_many")
  end

  it "checks action ID uniqueness within an Actions block" do
    first = Slack::UI::Checked::BlockElements::Button.new(
      text: Slack::UI::Checked.plain("First"),
      action_id: "same"
    )
    second = Slack::UI::Checked::BlockElements::Button.new(
      text: Slack::UI::Checked.plain("Second"),
      action_id: "same"
    )

    error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedBlocks::Actions.new(elements: [first, second])
    end
    error.issues.map(&.code).should eq ["actions.action_id.duplicate"]
    error.issues.map(&.path).should eq ["elements[1].action_id"]
  end

  it "implements the complete Divider wire contract" do
    minimum = JSON.parse(CheckedBlocks::Divider.new.to_json)
    full = JSON.parse(CheckedBlocks::Divider.new(block_id: "separator").to_json)

    minimum.should eq JSON.parse(%({"type":"divider"}))
    full.should eq JSON.parse(%({"type":"divider","block_id":"separator"}))
    CheckedBlocks::Divider.new(block_id: "✓" * 255)

    error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedBlocks::Divider.new(block_id: "✓" * 256)
    end
    error.issues.map(&.code).should eq ["divider.block_id.too_long"]
  end
end

private def checked_button(index : Int32) : Slack::UI::Checked::BlockElements::Button
  Slack::UI::Checked::BlockElements::Button.new(
    text: Slack::UI::Checked.plain("Button #{index}"),
    action_id: "action-#{index}"
  )
end

require "../../spec_helper"

private alias Checked = Slack::UI::Checked

describe "checked text and legacy snapshots" do
  it "serializes distinct plain text and markdown values" do
    plain = Checked::CompositionObjects::PlainText.new("Plain", emoji: true)
    markdown = Checked::CompositionObjects::Mrkdwn.new("*Markdown*", verbatim: true)

    JSON.parse(plain.to_json).should eq JSON.parse(<<-JSON)
      {"type":"plain_text","text":"Plain","emoji":true}
      JSON
    JSON.parse(markdown.to_json).should eq JSON.parse(<<-JSON)
      {"type":"mrkdwn","text":"*Markdown*","verbatim":true}
      JSON
  end

  it "reports unnamed button enum values as normal validation issues" do
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |_request|
      requests += 1
      HTTP::Client::Response.new(500)
    end

    error = expect_raises(Checked::ValidationError) do
      Checked::BlockElements::Button.new(
        text: Checked::CompositionObjects::PlainText.new("Invalid"),
        style: Checked::BlockElements::ButtonStyle.new(99)
      )
    end

    error.issues.map(&.code).should eq ["button.style.invalid"]
    requests.should eq 0
  end

  it "converts the real legacy TextSection result to a distinct checked snapshot" do
    legacy = Slack::UI::Components::TextSection.render("*Before*", markdown: true)
    checked = Checked::LegacyAdapter.section(legacy)
    checked.should be_a(Checked::Blocks::Section)
    checked.class.should_not eq legacy.class
    before = checked.to_json

    legacy.type = "not_section"
    if text = legacy.text
      text.text = "After"
      text.type = "plain_text"
      legacy.text = text
    end

    checked.to_json.should eq before
    JSON.parse(before)["text"]["type"].should eq "mrkdwn"
  end

  it "copies nested legacy field collections and checked getters" do
    legacy_fields = [Slack::UI::Blocks::Section::FieldText.new("One")]
    legacy = Slack::UI::Blocks::Section.new(fields: legacy_fields)
    checked = Checked::LegacyAdapter.section(legacy)
    before = checked.to_json

    legacy_fields << Slack::UI::Blocks::Section::FieldText.new("Two")
    changed = legacy_fields[0]
    changed.text = "Changed"
    legacy_fields[0] = changed
    checked.fields.try(&.clear)

    checked.to_json.should eq before
    JSON.parse(before)["fields"].as_a.size.should eq 1
  end

  it "rejects a mutable legacy discriminator during conversion" do
    legacy = Slack::UI::Components::TextSection.render("Text")
    if text = legacy.text
      text.type = "markdown-ish"
      legacy.text = text
    end

    error = expect_raises(Checked::ValidationError) do
      Checked::LegacyAdapter.section(legacy)
    end
    error.issues.map(&.code).should contain("legacy.text.type.invalid")
  end
end

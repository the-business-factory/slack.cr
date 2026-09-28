require "../../spec_helper"

private alias CheckedComposition = Slack::UI::Checked::CompositionObjects

describe "checked Block Kit composition objects" do
  it "serializes distinct text formats and preserves explicit false" do
    plain = CheckedComposition::PlainText.new("Plain", emoji: false)
    markdown = CheckedComposition::Mrkdwn.new("*Markdown*", verbatim: false)

    JSON.parse(plain.to_json).should eq JSON.parse(
      %({"type":"plain_text","text":"Plain","emoji":false})
    )
    JSON.parse(markdown.to_json).should eq JSON.parse(
      %({"type":"mrkdwn","text":"*Markdown*","verbatim":false})
    )
  end

  it "omits absent text formatting options" do
    plain = JSON.parse(CheckedComposition::PlainText.new("Plain").to_json)
    markdown = JSON.parse(CheckedComposition::Mrkdwn.new("Markdown").to_json)

    plain.as_h.has_key?("emoji").should be_false
    markdown.as_h.has_key?("verbatim").should be_false
  end

  it "validates text object lengths with structured issues" do
    CheckedComposition::PlainText.new("p" * 3000)
    CheckedComposition::Mrkdwn.new("m" * 3000)

    empty_error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedComposition::PlainText.new("")
    end
    empty_error.issues.map(&.code).should eq ["plain_text.text.empty"]
    empty_error.issues.map(&.path).should eq ["text"]

    long_error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedComposition::Mrkdwn.new("m" * 3001)
    end
    long_error.issues.map(&.code).should eq ["mrkdwn.text.too_long"]
  end

  it "serializes every confirmation field with checked text values" do
    confirmation = CheckedComposition::Confirmation.new(
      title: Slack::UI::Checked.plain("Confirm request"),
      text: Slack::UI::Checked.mrkdwn("Continue with *request 42*?"),
      confirm: Slack::UI::Checked.plain("Continue"),
      deny: Slack::UI::Checked.plain("Cancel"),
      style: CheckedComposition::ConfirmationStyle::Danger
    )

    JSON.parse(confirmation.to_json).should eq JSON.parse(<<-JSON)
      {
        "title":{"type":"plain_text","text":"Confirm request"},
        "text":{"type":"mrkdwn","text":"Continue with *request 42*?"},
        "confirm":{"type":"plain_text","text":"Continue"},
        "deny":{"type":"plain_text","text":"Cancel"},
        "style":"danger"
      }
      JSON
  end

  it "accepts confirmation limits and rejects values above them" do
    CheckedComposition::Confirmation.new(
      title: Slack::UI::Checked.plain("t" * 100),
      text: Slack::UI::Checked.mrkdwn("b" * 300),
      confirm: Slack::UI::Checked.plain("c" * 30),
      deny: Slack::UI::Checked.plain("d" * 30)
    )

    {
      "confirmation.title.too_long"   => {101, 1, 1, 1},
      "confirmation.text.too_long"    => {1, 301, 1, 1},
      "confirmation.confirm.too_long" => {1, 1, 31, 1},
      "confirmation.deny.too_long"    => {1, 1, 1, 31},
    }.each do |code, lengths|
      error = expect_raises(Slack::UI::Checked::ValidationError) do
        CheckedComposition::Confirmation.new(
          title: Slack::UI::Checked.plain("t" * lengths[0]),
          text: Slack::UI::Checked.mrkdwn("b" * lengths[1]),
          confirm: Slack::UI::Checked.plain("c" * lengths[2]),
          deny: Slack::UI::Checked.plain("d" * lengths[3])
        )
      end
      error.issues.map(&.code).should contain(code)
    end
  end

  it "reports unnamed confirmation styles as validation issues" do
    error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedComposition::Confirmation.new(
        title: Slack::UI::Checked.plain("Title"),
        text: Slack::UI::Checked.plain("Text"),
        confirm: Slack::UI::Checked.plain("Yes"),
        deny: Slack::UI::Checked.plain("No"),
        style: CheckedComposition::ConfirmationStyle.new(99)
      )
    end

    error.issues.map(&.code).should eq ["confirmation.style.invalid"]
  end
end

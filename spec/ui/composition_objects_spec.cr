require "../spec_helper"

private alias UIComposition = Slack::UI::CompositionObjects

describe "Block Kit composition objects" do
  it "serializes distinct text formats and preserves explicit false" do
    plain = UIComposition::PlainText.new("Plain", emoji: false)
    markdown = UIComposition::Mrkdwn.new("*Markdown*", verbatim: false)

    JSON.parse(plain.to_json).should eq JSON.parse(
      %({"type":"plain_text","text":"Plain","emoji":false})
    )
    JSON.parse(markdown.to_json).should eq JSON.parse(
      %({"type":"mrkdwn","text":"*Markdown*","verbatim":false})
    )
  end

  it "omits absent text formatting options" do
    plain = JSON.parse(UIComposition::PlainText.new("Plain").to_json)
    markdown = JSON.parse(UIComposition::Mrkdwn.new("Markdown").to_json)

    plain.as_h.has_key?("emoji").should be_false
    markdown.as_h.has_key?("verbatim").should be_false
  end

  it "validates text object lengths with structured issues" do
    UIComposition::PlainText.new("p" * 3000)
    UIComposition::Mrkdwn.new("m" * 3000)

    empty_error = expect_raises(Slack::UI::ValidationError) do
      UIComposition::PlainText.new("")
    end
    empty_error.issues.map(&.code).should eq ["plain_text.text.empty"]
    empty_error.issues.map(&.path).should eq ["text"]

    long_error = expect_raises(Slack::UI::ValidationError) do
      UIComposition::Mrkdwn.new("m" * 3001)
    end
    long_error.issues.map(&.code).should eq ["mrkdwn.text.too_long"]
  end

  it "serializes every confirmation field with text values" do
    confirmation = UIComposition::Confirmation.new(
      title: Slack::UI.plain("Confirm request"),
      text: Slack::UI.mrkdwn("Continue with *request 42*?"),
      confirm: Slack::UI.plain("Continue"),
      deny: Slack::UI.plain("Cancel"),
      style: UIComposition::ConfirmationStyle::Danger
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
    UIComposition::Confirmation.new(
      title: Slack::UI.plain("t" * 100),
      text: Slack::UI.mrkdwn("b" * 300),
      confirm: Slack::UI.plain("c" * 30),
      deny: Slack::UI.plain("d" * 30)
    )

    {
      "confirmation.title.too_long"   => {101, 1, 1, 1},
      "confirmation.text.too_long"    => {1, 301, 1, 1},
      "confirmation.confirm.too_long" => {1, 1, 31, 1},
      "confirmation.deny.too_long"    => {1, 1, 1, 31},
    }.each do |code, lengths|
      error = expect_raises(Slack::UI::ValidationError) do
        UIComposition::Confirmation.new(
          title: Slack::UI.plain("t" * lengths[0]),
          text: Slack::UI.mrkdwn("b" * lengths[1]),
          confirm: Slack::UI.plain("c" * lengths[2]),
          deny: Slack::UI.plain("d" * lengths[3])
        )
      end
      error.issues.map(&.code).should contain(code)
    end
  end

  it "reports unnamed confirmation styles as validation issues" do
    error = expect_raises(Slack::UI::ValidationError) do
      UIComposition::Confirmation.new(
        title: Slack::UI.plain("Title"),
        text: Slack::UI.plain("Text"),
        confirm: Slack::UI.plain("Yes"),
        deny: Slack::UI.plain("No"),
        style: UIComposition::ConfirmationStyle.new(99)
      )
    end

    error.issues.map(&.code).should eq ["confirmation.style.invalid"]
  end
end

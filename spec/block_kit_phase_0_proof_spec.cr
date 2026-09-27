require "./spec_helper"
require "./support/block_kit/prototype"

private alias Checked = Slack::UI::Checked
private alias CheckedProof = Slack::UI::Checked::Proof

describe "Block Kit Phase 0 executed proofs" do
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

  it "keeps modal snapshots stable after caller and builder mutation" do
    title = Checked::CompositionObjects::PlainText.new("Title")
    section = Checked::Blocks::Section.new(text: title)
    caller_blocks = [section]
    display = CheckedProof::DisplayModal.new(title: title, blocks: caller_blocks)
    before = display.to_json

    caller_blocks.clear
    display.blocks.clear
    display.to_json.should eq before

    builder = CheckedProof::FormModalBuilder.new(title: title, submit: title)
    builder.add(section)
    first = builder.build
    first_json = first.to_json
    builder.add(CheckedProof::ReusableSummary.new("Later").render)
    first.blocks.clear
    first.to_json.should eq first_json
  end

  it "uses modal on the wire while keeping display and form contracts distinct" do
    title = Checked::CompositionObjects::PlainText.new("Title")
    section = Checked::Blocks::Section.new(text: title)
    display = CheckedProof::DisplayModal.new(title: title, blocks: [section])
    form = CheckedProof::FormModal.new(title: title, submit: title, blocks: [section])

    JSON.parse(display.to_json)["type"].should eq "modal"
    JSON.parse(display.to_json).as_h.has_key?("submit").should be_false
    JSON.parse(form.to_json)["type"].should eq "modal"
    JSON.parse(form.to_json)["submit"]["text"].should eq "Title"
  end

  it "shows why the checked endpoint does not inherit current mutable request fields" do
    current = Slack::Api::ChatPostMessage.new(
      token: "xoxb-synthetic",
      channel: "C-before",
      text: "Text"
    )
    current.channel = "C-after"
    current.channel.should eq "C-after"
  end

  it "assembles and sends the checked envelope through direct result" do
    token = "xoxb-synthetic"
    section = Checked::Blocks::Section.new(
      text: Checked::CompositionObjects::Mrkdwn.new("*Result*")
    )
    message = CheckedProof::Message.new(fallback_text: "Result", blocks: [section])

    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .with(headers: {"Authorization" => "Bearer #{token}"})
      .to_return do |request|
        payload = JSON.parse(request.body || fail("expected request body"))
        payload["channel"].should eq "C-result"
        payload["text"].should eq "Result"
        payload["blocks"][0]["type"].should eq "section"
        HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/chat-post-success-section.json"))
      end

    request = CheckedProof::CheckedChatPostMessage.new(
      token: token,
      channel: "C-result",
      message: message
    )
    request.result.status_code.should eq 200
  end

  it "validates and sends the checked envelope through call" do
    token = "xoxb-synthetic"
    section = Checked::Blocks::Section.new(
      text: Checked::CompositionObjects::PlainText.new("Call")
    )
    message = CheckedProof::Message.new(fallback_text: "Call", blocks: [section])

    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .to_return(body: File.read("spec/fixtures/api/chat-post-success-section.json"))

    response = CheckedProof::CheckedChatPostMessage.new(
      token: token,
      channel: "C-call",
      message: message
    ).call
    response.should be_a(Slack::Models::Chat::PostMessage)
    response.ok?.should be_true
  end

  ["result", "call"].each do |method|
    it "rejects an invalid request before HTTP through #{method}" do
      requests = 0
      WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |_request|
        requests += 1
        HTTP::Client::Response.new(500)
      end
      section = Checked::Blocks::Section.new(
        text: Checked::CompositionObjects::PlainText.new("Invalid request")
      )
      message = CheckedProof::Message.new(fallback_text: "Invalid request", blocks: [section])
      request = CheckedProof::CheckedChatPostMessage.new(
        token: "xoxb-synthetic",
        channel: "",
        message: message
      )

      error = expect_raises(Checked::ValidationError) do
        method == "result" ? request.result : request.call
      end
      error.issues.map(&.code).should contain("chat_post_message.channel.empty")
      requests.should eq 0
    end
  end

  it "stores a separate checked endpoint snapshot" do
    legacy = Slack::UI::Components::TextSection.render("Before")
    checked = Checked::LegacyAdapter.section(legacy)
    caller_blocks = [checked]
    message = CheckedProof::Message.new(fallback_text: "Snapshot", blocks: caller_blocks)
    request = CheckedProof::CheckedChatPostMessage.new(
      token: "xoxb-synthetic",
      channel: "C-snapshot",
      message: message
    )
    before = request.to_json

    if text = legacy.text
      text.text = "After"
      legacy.text = text
    end
    caller_blocks.clear
    message.blocks.clear

    request.to_json.should eq before
  end
end

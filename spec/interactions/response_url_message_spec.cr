require "../spec_helper"

describe Slack::Interactions::ResponseUrlMessage do
  it "replaces the source message" do
    message = Slack::Interactions::ResponseUrlMessage.new(text: "Thanks for your request.", replace_original: true)

    JSON.parse(message.to_json).should eq(JSON.parse(%({"replace_original":true,"text":"Thanks for your request."})))
  end

  it "sends delete_original as the sole attribute" do
    message = Slack::Interactions::ResponseUrlMessage.delete_original

    JSON.parse(message.to_json).should eq(JSON.parse(%({"delete_original":true})))
  end

  it "posts a Block Kit reply in a thread" do
    blocks = Slack::UI::Message.new(fallback_text: "Build passed.", blocks: [
      Slack::UI::Blocks::Section.new(Slack::UI::CompositionObjects::Mrkdwn.new("Build *passed*.")),
    ])
    message = Slack::Interactions::ResponseUrlMessage.new(message: blocks,
      response_type: Slack::Interactions::ResponseType::InChannel, replace_original: false, thread_ts: "1710000000.000100")

    JSON.parse(message.to_json).should eq(JSON.parse(<<-JSON))
      {
        "response_type": "in_channel",
        "replace_original": false,
        "thread_ts": "1710000000.000100",
        "text": "Build passed.",
        "blocks": [{"type": "section", "text": {"type": "mrkdwn", "text": "Build *passed*."}}]
      }
      JSON
  end

  it "keeps the source message when a thread reply omits replace_original" do
    message = Slack::Interactions::ResponseUrlMessage.new(text: "Thread reply",
      response_type: :in_channel, thread_ts: "1710000000.000100")

    JSON.parse(message.to_json).should eq(JSON.parse(<<-JSON))
      {"response_type": "in_channel", "replace_original": false, "thread_ts": "1710000000.000100", "text": "Thread reply"}
      JSON
  end

  it "rejects a thread reply that replaces the source message" do
    error = expect_raises(Slack::UI::ValidationError) do
      Slack::Interactions::ResponseUrlMessage.new(text: "Thread reply",
        response_type: :in_channel, replace_original: true, thread_ts: "1710000000.000100")
    end
    error.issues.map(&.code).should eq ["response_url_message.thread_ts.replace_original"]
  end

  it "requires in_channel for a thread reply" do
    error = expect_raises(Slack::UI::ValidationError) do
      Slack::Interactions::ResponseUrlMessage.new(text: "Done.", thread_ts: "1710000000.000100")
    end
    error.issues.map(&.code).should eq ["response_url_message.thread_ts.requires_in_channel"]
  end

  it "rejects blank text" do
    error = expect_raises(Slack::UI::ValidationError) { Slack::Interactions::ResponseUrlMessage.new(text: "") }
    error.issues.map(&.code).should eq ["response_url_message.text.blank"]
  end
end

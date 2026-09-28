require "../spec_helper"

private def approval_message : Slack::UI::Message
  Slack::UI::Message.new(fallback_text: "Deploy 42 is ready.", blocks: [
    Slack::UI::Blocks::Section.new(Slack::UI::CompositionObjects::Mrkdwn.new("*Deploy 42* is ready."), block_id: "deploy"),
  ])
end

describe Slack::Commands::Response do
  it "answers with an ephemeral text message by default" do
    response = Slack::Commands::Response.new(text: "Only you can see this.")

    JSON.parse(response.to_json).should eq(JSON.parse(%({"response_type":"ephemeral","text":"Only you can see this."})))
  end

  it "shares a Block Kit message in the channel" do
    response = Slack::Commands::Response.new(message: approval_message,
      response_type: Slack::Interactions::ResponseType::InChannel)

    JSON.parse(response.to_json).should eq(JSON.parse(<<-JSON))
      {
        "response_type": "in_channel",
        "text": "Deploy 42 is ready.",
        "blocks": [{"type": "section", "block_id": "deploy", "text": {"type": "mrkdwn", "text": "*Deploy 42* is ready."}}]
      }
      JSON
  end

  it "rejects blank text" do
    error = expect_raises(Slack::UI::ValidationError) { Slack::Commands::Response.new(text: " ") }
    error.issues.map(&.code).should eq ["command_response.text.blank"]
  end
end

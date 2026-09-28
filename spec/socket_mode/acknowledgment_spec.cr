require "../spec_helper"

describe Slack::SocketMode::Acknowledgment do
  it "acknowledges an envelope without a payload" do
    ack = Slack::SocketMode::Acknowledgment.new("dbdd0ef3-1543-4f94-bfb4-133d0e6c1545")

    JSON.parse(ack.to_json).should eq(JSON.parse(%({"envelope_id":"dbdd0ef3-1543-4f94-bfb4-133d0e6c1545"})))
  end

  it "carries a modal errors response action as the payload" do
    errors = Slack::Interactions::ModalErrors.new({"request.reason" => "Enter at least 10 characters."})
    ack = Slack::SocketMode::Acknowledgment.new("E-SUBMIT", errors)

    JSON.parse(ack.to_json).should eq(JSON.parse(<<-JSON))
      {
        "envelope_id": "E-SUBMIT",
        "payload": {
          "response_action": "errors",
          "errors": {"request.reason": "Enter at least 10 characters."}
        }
      }
      JSON
  end

  it "carries block suggestion options as the payload" do
    option = Slack::UI::Checked::CompositionObjects::Option.new(
      text: Slack::UI::Checked::CompositionObjects::PlainText.new("Release 42"), value: "release-42")
    ack = Slack::SocketMode::Acknowledgment.new("E-SUGGEST", Slack::Interactions::BlockSuggestionResponse.new(options: [option]))

    JSON.parse(ack.to_json).should eq(JSON.parse(<<-JSON))
      {
        "envelope_id": "E-SUGGEST",
        "payload": {"options": [{"text": {"type": "plain_text", "text": "Release 42"}, "value": "release-42"}]}
      }
      JSON
  end
end

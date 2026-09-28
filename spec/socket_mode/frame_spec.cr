require "../spec_helper"

private def socket_frame(name : String) : String
  File.read(File.join(__DIR__, "../fixtures/socket_mode", "#{name}.json"))
end

private def envelope(name : String) : Slack::SocketMode::Envelope
  Slack::SocketMode::Frame.parse(socket_frame(name)).should be_a(Slack::SocketMode::Envelope)
end

describe Slack::SocketMode::Frame do
  it "decodes the hello frame with its connection count and refresh estimate" do
    hello = Slack::SocketMode::Frame.parse(socket_frame("hello")).should be_a(Slack::SocketMode::Hello)

    hello.num_connections.should eq(2)
    hello.approximate_connection_time.should eq(3600)
    hello.app_id.should eq("A-SYNTHETIC")
  end

  it "decodes each documented disconnect reason and keeps debug info raw" do
    {
      "disconnect_warning"           => Slack::SocketMode::Disconnect::Reason::Warning,
      "disconnect_refresh_requested" => Slack::SocketMode::Disconnect::Reason::RefreshRequested,
      "disconnect_link_disabled"     => Slack::SocketMode::Disconnect::Reason::LinkDisabled,
    }.each do |name, reason|
      disconnect = Slack::SocketMode::Frame.parse(socket_frame(name)).should be_a(Slack::SocketMode::Disconnect)
      disconnect.reason.should eq(reason)
      disconnect.debug_info.should eq(JSON.parse(%({"host":"wss-synthetic.slack.com"})))
    end
  end

  it "keeps an undocumented disconnect reason by name" do
    disconnect = Slack::SocketMode::Frame.parse(%({"type":"disconnect","reason":"too_many_websockets"}))
      .should be_a(Slack::SocketMode::Disconnect)

    disconnect.reason.should eq(Slack::SocketMode::Disconnect::Reason::Unknown)
    disconnect.reason_name.should eq("too_many_websockets")
    disconnect.debug_info.should be_nil
  end

  it "decodes an events_api envelope into the verified event it carries" do
    envelope = envelope("events_api_app_mention")

    envelope.envelope_id.should eq("57d6a792-4d35-4d0b-b6aa-3361493e1caf")
    envelope.kind.should eq(Slack::SocketMode::Envelope::Kind::EventsApi)
    envelope.accepts_response_payload?.should be_false
    envelope.retry_attempt.should eq(1)
    envelope.retry_reason.should eq("timeout")
    envelope.payload["event_id"].should eq("Ev-SYNTHETIC")

    verified = envelope.event.should be_a(Slack::VerifiedEvent)
    verified.team_id.should eq("T-SYNTHETIC")
    mention = verified.event.should be_a(Slack::Events::AppMentioned)
    mention.channel.should eq("C-SYNTHETIC")
    mention.user.should eq("U-SYNTHETIC")
  end

  it "decodes an interactive envelope into its block_actions interaction" do
    envelope = envelope("interactive_block_actions")

    envelope.kind.should eq(Slack::SocketMode::Envelope::Kind::Interactive)
    envelope.accepts_response_payload?.should be_true
    envelope.retry_attempt.should be_nil
    envelope.retry_reason.should be_nil

    block_action = envelope.interaction.should be_a(Slack::Interactions::BlockAction)
    button = block_action.decoded_actions.first.should be_a(Slack::Interactions::ButtonAction)
    button.action_id.should eq("deploy.approve")
    button.value.should eq("release-42")
  end

  it "decodes a slash_commands envelope into a command" do
    envelope = envelope("slash_commands")

    envelope.kind.should eq(Slack::SocketMode::Envelope::Kind::SlashCommands)
    command = envelope.command
    command.command.should eq("/deploy")
    command.api_app_id.should eq("A-SYNTHETIC")
    command.is_enterprise_install.should be_false
    command.decoded_usernames.map(&.id).should eq(["U0REVIEWER"])
  end

  it "raises TypeMismatch when the payload is read as the wrong kind" do
    events = envelope("events_api_app_mention")
    error = expect_raises(Slack::Interactions::TypeMismatch) { events.interaction }
    error.path.should eq("type")
    error.expected.should eq("interactive")
    error.actual.should eq("events_api")

    expect_raises(Slack::Interactions::TypeMismatch) { events.command }
    expect_raises(Slack::Interactions::TypeMismatch) { envelope("slash_commands").event }
  end

  it "keeps an envelope of an unknown kind so that it can be acknowledged" do
    envelope = Slack::SocketMode::Frame.parse(%({"type":"future_kind","envelope_id":"E-1","payload":{"a":1},"accepts_response_payload":false}))
      .should be_a(Slack::SocketMode::Envelope)

    envelope.kind.should eq(Slack::SocketMode::Envelope::Kind::Unknown)
    envelope.type.should eq("future_kind")
    envelope.payload.should eq(JSON.parse(%({"a":1})))
    expect_raises(Slack::Interactions::TypeMismatch) { envelope.event }
  end

  it "returns other frames raw" do
    frame = Slack::SocketMode::Frame.parse(%({"type":"future_frame","detail":true}))
      .should be_a(Slack::SocketMode::UnknownFrame)

    frame.type.should eq("future_frame")
    frame.raw.should eq(JSON.parse(%({"type":"future_frame","detail":true})))
  end

  it "rejects a command payload with a duplicate routing field" do
    duplicate = socket_frame("slash_commands").sub(%("team_id": "T-SYNTHETIC",), %("team_id": "T-SYNTHETIC", "team_id": "T-OTHER",))
    envelope = Slack::SocketMode::Frame.parse(duplicate).should be_a(Slack::SocketMode::Envelope)

    error = expect_raises(Slack::Auth::RequestAuthorizationError) { envelope.command }
    error.reason.should eq(:duplicate_routing_field)
  end

  it "reports a malformed envelope field by path" do
    error = expect_raises(Slack::Interactions::TypeMismatch) do
      Slack::SocketMode::Frame.parse(%({"type":"interactive","envelope_id":7,"payload":{}}))
    end
    error.path.should eq("envelope_id")
  end
end

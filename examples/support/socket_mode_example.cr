require "../../src/slack"

module OfflineSocketModeExample
  # Independently authored frames in the order that one connection can receive
  # them. A Socket Mode client reads these from the WebSocket.
  FRAMES = [
    %q({"type":"hello","num_connections":1,"debug_info":{"approximate_connection_time":3600},"connection_info":{"app_id":"A-SYNTHETIC"}}),
    %q({"envelope_id":"E-EVENT","type":"events_api","accepts_response_payload":false,"payload":{"type":"event_callback","token":"synthetic","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC","event_id":"Ev-SYNTHETIC","event_time":1710000000,"event":{"type":"app_mention","user":"U-SYNTHETIC","channel":"C-SYNTHETIC","text":"<@U0BOT> status","ts":"1710000000.000100","event_ts":"1710000000.000100"}}}),
    %q({"envelope_id":"E-COMMAND","type":"slash_commands","accepts_response_payload":true,"payload":{"api_app_id":"A-SYNTHETIC","team_id":"T-SYNTHETIC","channel_id":"C-SYNTHETIC","channel_name":"general","user_id":"U-SYNTHETIC","user_name":"synthetic.user","command":"/request","text":"test environment","response_url":"https://hooks.slack.com/commands/T-SYNTHETIC/1/synthetic","trigger_id":"1710000000.synthetic.trigger"}}),
    %q({"envelope_id":"E-SUBMIT","type":"interactive","accepts_response_payload":true,"payload":{"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-SYNTHETIC"},"view":{"type":"modal","callback_id":"request.reason","state":{"values":{"request.reason":{"reason":{"type":"plain_text_input","value":"test"}}}}}}}),
    %q({"type":"disconnect","reason":"refresh_requested","debug_info":{"host":"wss-synthetic.slack.com"}}),
  ]

  # Returns the acknowledgment for an envelope, or nil for other frames.
  def self.handle(text : String, output : IO) : Slack::SocketMode::Acknowledgment?
    case frame = Slack::SocketMode::Frame.parse(text)
    in Slack::SocketMode::Hello
      output.puts "Connected as #{frame.app_id} (#{frame.num_connections} of 10 connections)"
      nil
    in Slack::SocketMode::Disconnect
      output.puts "Disconnect: #{frame.reason_name}"
      nil
    in Slack::SocketMode::UnknownFrame
      nil
    in Slack::SocketMode::Envelope
      Slack::SocketMode::Acknowledgment.new(frame.envelope_id, respond(frame, output))
    end
  end

  # Decodes each payload with the same rules as the HTTP path.
  private def self.respond(envelope : Slack::SocketMode::Envelope, output : IO) : Slack::SocketMode::Acknowledgment::Payload?
    decoder = Slack::Decoder.default
    case envelope.kind
    in .events_api?
      if (verified = decoder.event(envelope.payload_json)).is_a?(Slack::VerifiedEvent) && (mention = verified.event).is_a?(Slack::Events::AppMentioned)
        output.puts "Mentioned in #{mention.channel}"
      end
    in .slash_commands?
      command = decoder.command(envelope.payload_json, :json)
      output.puts "Command #{command.command}: #{command.text}"
    in .interactive?
      review(decoder.interaction(envelope.payload_json, :json), output)
    in .unknown?
      nil
    end
  end

  # Business validation of the submitted reason. Send a response payload only
  # when the envelope accepts one.
  private def self.review(interaction : Slack::Interaction, output : IO) : Slack::SocketMode::Acknowledgment::Payload?
    return unless interaction.is_a?(Slack::Interactions::ViewSubmission)
    reason = interaction.plain_text?("request.reason", "reason")
    return if reason && reason.strip.size >= 10

    output.puts "Rejected short reason"
    Slack::Interactions::ModalErrors.new({"request.reason" => "Explain why you need this request (at least 10 characters)."})
  end

  def self.run(output : IO = STDOUT) : Array(String)
    FRAMES.compact_map { |text| handle(text, output).try(&.to_json) }
  end
end

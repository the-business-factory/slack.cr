require "../../src/slack"

module OfflineModalClearExample
  # Independently authored incoming state, not derived from an outbound modal.
  SUBMISSION = %q({"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-SYNTHETIC"},"view":{"type":"modal","callback_id":"request.reason","state":{"values":{"request.reason":{"reason":{"type":"plain_text_input","value":"Need a test environment."}}}}}})

  def self.run(output : IO = STDOUT) : HTTP::Client::Response
    signing_secret = Slack.settings.signing_secret
    begin
      Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
      body = URI::Params.encode({"payload" => SUBMISSION})
      timestamp = Time.utc.to_unix.to_s
      headers = HTTP::Headers{
        "Content-Type"              => "application/x-www-form-urlencoded",
        "X-Slack-Request-Timestamp" => timestamp,
        "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
      }
      interaction = Slack.process_interaction(HTTP::Request.new("POST", "/interactions", headers, body))
      raise "Expected view submission" unless interaction.is_a?(Slack::Interactions::ViewSubmission)
      view = interaction.view
      raise "Unexpected form" unless view && view["callback_id"].as_s == "request.reason"
      reason = interaction.plain_text?("request.reason", "reason")
      raise "Expected a useful reason" unless reason && reason.strip.size >= 10

      # After accepting the input, the application sends these status, headers
      # and body within three seconds. Clear closes the entire modal stack;
      # an empty HTTP 200 would close only the submitted view.
      response = HTTP::Client::Response.new(200,
        headers: HTTP::Headers{"Content-Type" => "application/json"},
        body: Slack::Interactions::ModalClear.new.to_json)
      output.puts "Accepted reason: #{reason} (prepared HTTP 200 clear)"
      response
    ensure
      Slack.configure(&.signing_secret=(signing_secret))
    end
  end
end

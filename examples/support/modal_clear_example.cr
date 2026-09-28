require "../../src/slack"
require "../../src/slack/testing"

module OfflineModalClearExample
  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  # Independently authored incoming state, not derived from an outbound modal.
  SUBMISSION = %q({"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-SYNTHETIC"},"view":{"type":"modal","callback_id":"request.reason","state":{"values":{"request.reason":{"reason":{"type":"plain_text_input","value":"Need a test environment."}}}}}})

  def self.run(output : IO = STDOUT) : HTTP::Client::Response
    body = URI::Params.encode({"payload" => SUBMISSION})
    request = Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, path: "/interactions", content_type: "application/x-www-form-urlencoded")
    interaction = Slack::Interactions.parse(VERIFIER.verify(request).body)
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
  end
end

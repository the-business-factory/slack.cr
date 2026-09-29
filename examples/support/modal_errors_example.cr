require "../../src/slack"
require "../../src/slack/testing"

module OfflineModalErrorsExample
  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  # Independently authored incoming state, not derived from an outbound modal.
  INVALID_SUBMISSION = %q({"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-SYNTHETIC"},"view":{"type":"modal","callback_id":"request.reason","state":{"values":{"request.reason":{"reason":{"type":"plain_text_input","value":"test"}}}}}})
  VALID_SUBMISSION   = %q({"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-SYNTHETIC"},"view":{"type":"modal","callback_id":"request.reason","state":{"values":{"request.reason":{"reason":{"type":"plain_text_input","value":"Need a test environment."}}}}}})

  # An application route can copy this prepared status, headers and body to its
  # HTTP response. Verification precedes business validation.
  def self.handle(request : HTTP::Request) : HTTP::Client::Response
    interaction = Slack::Interactions.parse(VERIFIER.verify(request).body)
    unless interaction.is_a?(Slack::Interactions::ViewSubmission)
      raise "Expected view submission"
    end
    view = interaction.view
    raise "Unexpected form" unless view && view.callback_id == "request.reason"

    reason = interaction.plain_text?("request.reason", "reason")
    if reason.nil? || reason.strip.size < 10
      errors = Slack::Interactions::ModalErrors.new({
        "request.reason" => "Explain why you need this request (at least 10 characters).",
      })
      HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "application/json"}, body: errors.to_json)
    else
      # Save the valid reason in the application. An empty acknowledgment closes
      # the submitted view; no additional response action is needed.
      HTTP::Client::Response.new(200, body: "")
    end
  end

  def self.signed_request(payload : String) : HTTP::Request
    body = URI::Params.encode({"payload" => payload})
    Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, path: "/interactions", content_type: "application/x-www-form-urlencoded")
  end

  def self.run(output : IO = STDOUT) : Tuple(HTTP::Client::Response, HTTP::Client::Response)
    rejected = handle(signed_request(INVALID_SUBMISSION))
    accepted = handle(signed_request(VALID_SUBMISSION))
    output.puts "Rejected short reason; accepted corrected reason (HTTP 200)."
    {rejected, accepted}
  end
end

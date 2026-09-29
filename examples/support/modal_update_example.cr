require "../../src/slack"
require "../../src/slack/testing"

module OfflineModalUpdateExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  # Independently authored incoming state, not derived from an outbound modal.
  SUBMISSION = %q({"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-SYNTHETIC"},"view":{"type":"modal","callback_id":"request.reason","private_metadata":"42","state":{"values":{"request.reason":{"reason":{"type":"plain_text_input","value":"Need a test environment."}}}}}})

  # An application route copies the prepared status, headers, and body to its
  # HTTP response within three seconds. Verify before reading application state.
  def self.handle(request : HTTP::Request) : HTTP::Client::Response
    interaction = Slack::Interactions.parse(VERIFIER.verify(request).body)
    unless interaction.is_a?(Slack::Interactions::ViewSubmission)
      raise "Expected view submission"
    end
    submitted = interaction.view
    raise "Unexpected form" unless submitted && submitted.callback_id == "request.reason"
    reason = interaction.plain_text?("request.reason", "reason") || raise "Missing reason"
    # Bound the display preview so a valid long input fits the Section text limit.
    preview = reason.size > 200 ? "#{reason[0, 200]}…" : reason

    updated = UI.form_modal(title: UI.plain("Review request"), submit: UI.plain("Save"),
      callback_id: "request.review", private_metadata: submitted.private_metadata || raise "Missing metadata") do |builder|
      builder.section(UI.plain("Choose an owner for: #{preview}"))
      # Keep the submitted input IDs. Slack owns remote input state; this example
      # checks the response bytes and does not simulate state preservation.
      builder.input(label: UI.plain("Reason"), block_id: "request.reason",
        element: UI::BlockElements::PlainTextInput.new(action_id: "reason", multiline: true))
      builder.input(label: UI.plain("Owner"), block_id: "request.owner",
        element: UI::BlockElements::UsersSelect.new(action_id: "owner"))
    end
    acknowledgment = Slack::Interactions::ModalUpdate.new(updated)
    HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "application/json"}, body: acknowledgment.to_json)
  end

  def self.run(output : IO = STDOUT) : HTTP::Client::Response
    body = URI::Params.encode({"payload" => SUBMISSION})
    request = Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, path: "/interactions", content_type: "application/x-www-form-urlencoded")
    response = handle(request)
    output.puts "Prepared updated form with retained request.reason/reason IDs (HTTP #{response.status_code})."
    response
  end
end

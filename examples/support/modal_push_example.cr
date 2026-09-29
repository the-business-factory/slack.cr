require "../../src/slack"
require "../../src/slack/testing"

module OfflineModalPushExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  # Independently authored incoming state, not derived from an outbound view.
  SUBMISSION = %q({"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-SYNTHETIC"},"view":{"type":"modal","callback_id":"request.reason","private_metadata":"42","state":{"values":{"request.reason":{"reason":{"type":"plain_text_input","value":"Need a test environment."}}}}}})

  # A real route copies this prepared status, headers and body to its response
  # within three seconds. Verify the original request before using its state.
  def self.handle(request : HTTP::Request) : HTTP::Client::Response
    interaction = Slack::Interactions.parse(VERIFIER.verify(request).body)
    unless interaction.is_a?(Slack::Interactions::ViewSubmission)
      raise "Expected view submission"
    end
    view = interaction.view
    raise "Unexpected form" unless view && view.callback_id == "request.reason"
    reason = interaction.plain_text?("request.reason", "reason") || raise "Missing reason"

    next_view = UI.form_modal(title: UI.plain("Delivery details"), submit: UI.plain("Save"),
      close: UI.plain("Back"), callback_id: "request.delivery", private_metadata: view.private_metadata || raise "Missing metadata") do |builder|
      builder.section(UI.plain("Reason: #{reason}"))
      builder.input(label: UI.plain("Delivery note"), block_id: "delivery",
        element: UI::BlockElements::PlainTextInput.new(action_id: "note", multiline: true))
    end
    acknowledgment = Slack::Interactions::ModalPush.new(next_view)
    HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "application/json"}, body: acknowledgment.to_json)
  end

  def self.signed_request : HTTP::Request
    body = URI::Params.encode({"payload" => SUBMISSION})
    Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, path: "/interactions", content_type: "application/x-www-form-urlencoded")
  end

  def self.run(output : IO = STDOUT) : HTTP::Client::Response
    response = handle(signed_request)
    output.puts "Prepared delivery form from signed submission (HTTP #{response.status_code})."
    response
  end
end

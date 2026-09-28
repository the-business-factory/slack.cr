require "../../src/slack"

module OfflineModalUpdateExample
  alias UI = Slack::UI

  # Independently authored incoming state, not derived from an outbound modal.
  SUBMISSION = %q({"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-SYNTHETIC"},"view":{"type":"modal","callback_id":"request.reason","private_metadata":"42","state":{"values":{"request.reason":{"reason":{"type":"plain_text_input","value":"Need a test environment."}}}}}})

  # An application route copies the prepared status, headers, and body to its
  # HTTP response within three seconds. Verify before reading application state.
  def self.handle(request : HTTP::Request) : HTTP::Client::Response
    interaction = Slack.process_interaction(request)
    unless interaction.is_a?(Slack::Interactions::ViewSubmission)
      raise "Expected view submission"
    end
    submitted = interaction.view
    raise "Unexpected form" unless submitted && submitted["callback_id"].as_s == "request.reason"
    reason = interaction.plain_text?("request.reason", "reason") || raise "Missing reason"
    # Bound the display preview so a valid long input fits the Section text limit.
    preview = reason.size > 200 ? "#{reason[0, 200]}…" : reason

    updated = UI.form_modal(title: UI.plain("Review request"), submit: UI.plain("Save"),
      callback_id: "request.review", private_metadata: submitted["private_metadata"].as_s) do |builder|
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
      response = handle(HTTP::Request.new("POST", "/interactions", headers, body))
      output.puts "Prepared updated form with retained request.reason/reason IDs (HTTP #{response.status_code})."
      response
    ensure
      Slack.configure(&.signing_secret=(signing_secret))
    end
  end
end

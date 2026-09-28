require "../../src/slack"

module OfflineModalPushExample
  alias UI = Slack::UI

  # Independently authored incoming state, not derived from an outbound view.
  SUBMISSION = %q({"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-SYNTHETIC"},"view":{"type":"modal","callback_id":"request.reason","private_metadata":"42","state":{"values":{"request.reason":{"reason":{"type":"plain_text_input","value":"Need a test environment."}}}}}})

  # A real route copies this prepared status, headers and body to its response
  # within three seconds. Verify the original request before using its state.
  def self.handle(request : HTTP::Request) : HTTP::Client::Response
    interaction = Slack.process_interaction(request)
    unless interaction.is_a?(Slack::Interactions::ViewSubmission)
      raise "Expected view submission"
    end
    view = interaction.view
    raise "Unexpected form" unless view && view["callback_id"].as_s == "request.reason"
    reason = interaction.plain_text?("request.reason", "reason") || raise "Missing reason"

    next_view = UI.form_modal(title: UI.plain("Delivery details"), submit: UI.plain("Save"),
      close: UI.plain("Back"), callback_id: "request.delivery", private_metadata: view["private_metadata"].as_s) do |builder|
      builder.section(UI.plain("Reason: #{reason}"))
      builder.input(label: UI.plain("Delivery note"), block_id: "delivery",
        element: UI::BlockElements::PlainTextInput.new(action_id: "note", multiline: true))
    end
    acknowledgment = Slack::Interactions::ModalPush.new(next_view)
    HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "application/json"}, body: acknowledgment.to_json)
  end

  def self.signed_request : HTTP::Request
    body = URI::Params.encode({"payload" => SUBMISSION})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "Content-Type"              => "application/x-www-form-urlencoded",
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }
    HTTP::Request.new("POST", "/interactions", headers, body)
  end

  def self.run(output : IO = STDOUT) : HTTP::Client::Response
    signing_secret = Slack.settings.signing_secret
    begin
      Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
      response = handle(signed_request)
      output.puts "Prepared delivery form from signed submission (HTTP #{response.status_code})."
      response
    ensure
      Slack.configure(&.signing_secret=(signing_secret))
    end
  end
end

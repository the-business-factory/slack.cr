require "../../src/slack"

module OfflineEventDeliveryExample
  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  # Independently authored retried delivery of an event type the app does not handle.
  BODY = %q({"type":"event_callback","token":"synthetic-legacy-token","api_app_id":"A-SYNTHETIC","team_id":"T-SYNTHETIC","event_id":"Ev-SYNTHETIC","event_time":1789232400,"is_ext_shared_channel":false,"authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}],"event":{"type":"synthetic_future_event","user":"U-SYNTHETIC","event_ts":"1789232400.000001"}})

  def self.run(output : IO = STDOUT) : HTTP::Client::Response
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "Content-Type"              => "application/json",
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(SIGNING_SECRET, timestamp, BODY).compute,
      "X-Slack-Retry-Num"         => "1",
      "X-Slack-Retry-Reason"      => "http_timeout",
    }
    request = HTTP::Request.new("POST", "/slack/events", headers, BODY)
    envelope = Slack::Events.parse(VERIFIER.verify(request).body)
    raise "Expected an event callback" unless envelope.is_a?(Slack::VerifiedEvent)
    delivery = Slack::Events::Delivery.from_headers(request.headers)

    # Acknowledge within three seconds, also for event types the app does not handle.
    case event = envelope.event
    when Slack::Events::Unknown
      output.puts "Skipped #{event.type} #{envelope.event_id} (retry #{delivery.retry_num}: #{delivery.retry_reason})"
    else
      output.puts "Handled #{event.type} #{envelope.event_id}"
    end
    HTTP::Client::Response.new(200)
  end
end

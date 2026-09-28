require "../../src/slack"

module OfflineEventCatalogExample
  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  ENVELOPE = %q({"type":"event_callback","token":"synthetic-legacy-token","api_app_id":"A-SYNTHETIC","team_id":"T-SYNTHETIC","event_id":"%s","event_time":1789232400,"authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}],"event":%s})

  # Independently authored deliveries: three app events, a message with a
  # subtype that the library does not map, and a rate-limit notice.
  BODIES = [
    ENVELOPE % {"Ev-LINK", %q({"type":"link_shared","channel":"C-SYNTHETIC","user":"U-SHARER","message_ts":"1789232400.000100","unfurl_id":"C-SYNTHETIC.unfurl","source":"conversations_history","is_bot_user_member":true,"links":[{"domain":"example.com","url":"https://example.com/tickets/42"}]})},
    ENVELOPE % {"Ev-JOIN", %q({"type":"member_joined_channel","user":"U-NEWCOMER","channel":"C-SYNTHETIC","channel_type":"C","team":"T-SYNTHETIC","inviter":"U-INVITER"})},
    ENVELOPE % {"Ev-TOPIC", %q({"type":"message","subtype":"channel_topic","channel":"C-SYNTHETIC","channel_type":"channel","user":"U-EDITOR","topic":"Release week","text":"<@U-EDITOR> set the channel topic: Release week","ts":"1789232400.000200","event_ts":"1789232400.000200"})},
    ENVELOPE % {"Ev-FUTURE", %q({"type":"message","subtype":"synthetic_future_subtype","channel":"C-SYNTHETIC","channel_type":"channel","ts":"1789232400.000300","event_ts":"1789232400.000300"})},
    %q({"type":"app_rate_limited","token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","minute_rate_limited":1789232400,"api_app_id":"A-SYNTHETIC"}),
  ]

  def self.run(output : IO = STDOUT) : Nil
    BODIES.each { |body| route(Slack::Events.parse(VERIFIER.verify(signed(body)).body), output) }
  end

  private def self.route(payload : Slack::VerifiedEvent | Slack::UrlVerification | Slack::AppRateLimited, output : IO) : Nil
    case payload
    in Slack::AppRateLimited
      output.puts "Rate limited for #{payload.team_id} since #{payload.minute_rate_limited.to_rfc3339}"
    in Slack::UrlVerification
      output.puts "URL verification"
    in Slack::VerifiedEvent
      route(payload.event, output)
    end
  end

  private def self.route(event : Slack::Event, output : IO) : Nil
    case event
    when Slack::Events::LinkShared
      output.puts "Unfurl #{event.links.map(&.url).join(", ")} in #{event.channel} (#{event.unfurl_id})"
    when Slack::Events::MemberJoinedChannel
      output.puts "Welcome #{event.user} to #{event.channel}, invited by #{event.inviter}"
    when Slack::Events::Message::ChannelTopic
      output.puts "Topic of #{event.channel} is now #{event.topic}"
    when Slack::Events::Message
      output.puts "Message subtype #{event.subtype} in #{event.channel}"
    else
      output.puts "Skipped #{event.type}"
    end
  end

  private def self.signed(body : String) : HTTP::Request
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "Content-Type"              => "application/json",
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(SIGNING_SECRET, timestamp, body).compute,
    }
    HTTP::Request.new("POST", "/slack/events", headers, body)
  end
end

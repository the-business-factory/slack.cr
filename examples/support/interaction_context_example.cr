require "../../src/slack"
require "../../src/slack/testing"
require "webmock"
require "./webmock_transport"

# Reads where each signed interaction happened and uses that context to reply.
module OfflineInteractionContextExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  TOKEN = "xoxb-synthetic-interaction-context"

  def self.signed(payload : String) : HTTP::Request
    body = URI::Params.encode({"payload" => payload})
    Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, path: "/interactions", content_type: "application/x-www-form-urlencoded")
  end

  # Returns the chat.update request body that the approval click produced.
  def self.run(output : IO = STDOUT) : JSON::Any
    updates = install_transport

    # Independently authored Slack payloads, not derived from outbound values.
    click = %({"type":"block_actions","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-REVIEWER"},"api_app_id":"A-SYNTHETIC","container":{"type":"message","message_ts":"1710000000.000100","channel_id":"C-RELEASES","is_ephemeral":false},"channel":{"id":"C-RELEASES","name":"releases"},"message":{"type":"message","ts":"1710000000.000100","text":"Approve release 2.0?"},"actions":[{"type":"button","block_id":"decision","action_id":"approve","value":"2.0","action_ts":"1710000001.000100"}]})
    case interaction = Slack::Interactions.parse(VERIFIER.verify(signed(click)).body)
    when Slack::Interactions::BlockAction
      approve(interaction, output)
    else
      raise "Expected block action"
    end

    submission = %({"type":"view_submission","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-REVIEWER"},"api_app_id":"A-SYNTHETIC","view":{"id":"V-SHARE","type":"modal","callback_id":"share_notes","private_metadata":"release-2.0","state":{"values":{"target":{"channel":{"type":"conversations_select","selected_conversation":"C-ANNOUNCE"}}}}},"response_urls":[{"block_id":"target","action_id":"channel","channel_id":"C-ANNOUNCE","response_url":"https://hooks.slack.com/app/A-SYNTHETIC/1/synthetic"}]})
    case interaction = Slack::Interactions.parse(VERIFIER.verify(signed(submission)).body)
    when Slack::Interactions::ViewSubmission
      release = interaction.view.try(&.private_metadata) || raise "Missing release"
      interaction.response_urls.each do |target|
        # The application sends the reply to target.response_url; this example does not.
        output.puts "Share #{release} notes in #{target.channel_id} (acknowledged 200)"
      end
    else
      raise "Expected view submission"
    end

    closed = %({"type":"view_closed","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-REVIEWER"},"api_app_id":"A-SYNTHETIC","view":{"id":"V-SHARE","type":"modal","callback_id":"share_notes"},"is_cleared":true})
    case interaction = Slack::Interactions.parse(VERIFIER.verify(signed(closed)).body)
    when Slack::Interactions::ViewClosed
      scope = interaction.is_cleared ? "all views" : "one view"
      output.puts "Closed #{scope} of #{interaction.view.try(&.callback_id)}"
    else
      raise "Expected view closed"
    end

    updates.first? || raise "Missing chat.update"
  end

  private def self.approve(interaction : Slack::Interactions::BlockAction, output : IO) : Nil
    case container = interaction.container
    when Slack::Interactions::Container::Message
      # chat.update cannot change an ephemeral message; reply through response_url instead.
      return output.puts "Ephemeral click; use response_url" if container.is_ephemeral
      channel_name = interaction.channel.try(&.name) || container.channel_id
      approved = UI.message(fallback_text: "Release 2.0 approved.") do |builder|
        builder.section(UI.mrkdwn("*Release 2.0 approved.*"), block_id: "decision.done")
      end
      client = Slack::Api::Client.new(token: TOKEN, transport: OfflineExample::WebMockTransport.new)
      client.call(Slack::Api::ChatUpdate.new(channel: container.channel_id, ts: container.message_ts, message: approved))
      output.puts "Approved in ##{channel_name} at #{container.message_ts}"
    else
      output.puts "Ignored click outside a message"
    end
  end

  # Returns the chat.update request bodies in send order.
  private def self.install_transport : Array(JSON::Any)
    WebMock.allow_net_connect = false
    updates = [] of JSON::Any
    WebMock.stub(:post, "https://slack.com/api/chat.update").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing update")
      updates << wire
      HTTP::Client::Response.new(200, body: {ok: true, channel: wire["channel"], ts: wire["ts"], text: wire["text"]}.to_json)
    end
    updates
  end
end

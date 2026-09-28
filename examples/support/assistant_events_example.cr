require "../../src/slack"

module OfflineAssistantEventsExample
  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  ENVELOPE = %q({"type":"event_callback","token":"synthetic-legacy-token","api_app_id":"A-SYNTHETIC","team_id":"T-SYNTHETIC","event_id":"%s","event_time":1789232400,"authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}],"event":%s})

  # Independently authored deliveries: an assistant thread opens, its context
  # changes, Slack titles the thread root, the viewed entities change, and a
  # user renames and stops an agent session.
  BODIES = [
    ENVELOPE % {"Ev-START", %q({"type":"assistant_thread_started","assistant_thread":{"user_id":"U-ASKER","context":{"channel_id":"C-VIEWED","team_id":"T-SYNTHETIC"},"channel_id":"D-ASSISTANT","thread_ts":"1789232400.000100"},"event_ts":"1789232400.000200"})},
    ENVELOPE % {"Ev-CONTEXT", %q({"type":"assistant_thread_context_changed","assistant_thread":{"user_id":"U-ASKER","context":{},"channel_id":"D-ASSISTANT","thread_ts":"1789232400.000100"},"event_ts":"1789232400.000300"})},
    ENVELOPE % {"Ev-ROOT", %q({"type":"message","subtype":"message_changed","channel":"D-ASSISTANT","channel_type":"im","hidden":true,"ts":"1789232400.000400","event_ts":"1789232400.000400","message":{"type":"message","subtype":"assistant_app_thread","user":"U-ASKER","text":"Trip planning","ts":"1789232400.000100","thread_ts":"1789232400.000100","assistant_app_thread":{"title":"Trip planning","title_blocks":[],"artifacts":[]}}})},
    ENVELOPE % {"Ev-VIEW", %q({"type":"app_context_changed","context":{"entities":[{"type":"slack#/types/channel_id","value":"C-VIEWED","team_id":"T-SYNTHETIC"}]}})},
    ENVELOPE % {"Ev-TITLE", %q({"type":"agent_session_title_changed","channel":"C-AGENT","user":"U-ASKER","thread_ts":"1789232400.000500","event_ts":"1789232400.000600","title":"Bora Bora trip prep"})},
    ENVELOPE % {"Ev-STOP", %q({"type":"agent_session_stopped","channel":"C-AGENT","user":"U-ASKER","thread_ts":"1789232400.000500","event_ts":"1789232400.000700","streaming_message_ts":["1789232400.000550"]})},
  ]

  def self.run(output : IO = STDOUT) : Nil
    BODIES.each do |body|
      envelope = Slack::Events.parse(VERIFIER.verify(signed(body)).body)
      route(envelope.event, output) if envelope.is_a?(Slack::VerifiedEvent)
    end
  end

  private def self.route(event : Slack::Event, output : IO) : Nil
    case event
    when Slack::Events::AssistantThreadStarted
      thread = event.assistant_thread
      output.puts "Thread #{thread.thread_ts} in #{thread.channel_id} opened while #{thread.user_id} views #{viewed_channel(thread)}"
    when Slack::Events::AssistantThreadContextChanged
      output.puts "Thread #{event.assistant_thread.thread_ts} now views #{viewed_channel(event.assistant_thread)}"
    when Slack::Events::Message::MessageChanged
      message = event.message
      title = message.assistant_app_thread.try(&.title)
      output.puts "Thread root #{message.ts} titled #{title}" if message.subtype == "assistant_app_thread"
    when Slack::Events::AppContextChanged
      output.puts "Viewing #{event.context.entities.map(&.value).join(", ")}"
    when Slack::Events::AgentSessionTitleChanged
      output.puts "Session #{event.thread_ts} renamed to #{event.title}"
    when Slack::Events::AgentSessionStopped
      output.puts "Stop work in #{event.channel} #{event.thread_ts}; streams stopped: #{event.streaming_message_ts.size}"
    else
      output.puts "Skipped #{event.type}"
    end
  end

  private def self.viewed_channel(thread : Slack::EventData::AssistantThread) : String
    thread.context.try(&.channel_id) || "no channel"
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

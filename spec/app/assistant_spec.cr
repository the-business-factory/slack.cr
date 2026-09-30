require "../spec_helper"
require "../../src/slack/testing"
require "../support/app/signed_request"

# Payloads and expected request bodies are authored independently from:
# https://docs.slack.dev/reference/events/assistant_thread_started
# https://docs.slack.dev/reference/events/assistant_thread_context_changed
# https://docs.slack.dev/reference/events/message.im
# https://docs.slack.dev/reference/methods/assistant.threads.setSuggestedPrompts
# https://docs.slack.dev/reference/methods/assistant.threads.setStatus
# https://docs.slack.dev/reference/methods/assistant.threads.setTitle
# https://docs.slack.dev/reference/methods/chat.startStream
# https://docs.slack.dev/reference/methods/chat.appendStream
# https://docs.slack.dev/reference/methods/chat.stopStream
# https://docs.slack.dev/reference/methods/conversations.replies
# https://docs.slack.dev/reference/methods/chat.update
private AUTHORIZATIONS = %("authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}])

private THREAD_STARTED = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"assistant_thread_started",
            "assistant_thread":{"user_id":"U-USER","channel_id":"D-ASSISTANT","thread_ts":"1729999327.187299",
                                "context":{"channel_id":"C-VIEWED","team_id":"T-SYNTHETIC","enterprise_id":"E-SYNTHETIC"}},
            "event_ts":"1729999327.187299"},
   "type":"event_callback","event_id":"Ev-STARTED","event_time":1729999327,#{AUTHORIZATIONS}}
  JSON

private CONTEXT_CHANGED = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"assistant_thread_context_changed",
            "assistant_thread":{"user_id":"U-USER","channel_id":"D-ASSISTANT","thread_ts":"1729999327.187299",
                                "context":{"channel_id":"C-OTHER","team_id":"T-SYNTHETIC"}},
            "event_ts":"1729999400.000100"},
   "type":"event_callback","event_id":"Ev-CHANGED","event_time":1729999400,#{AUTHORIZATIONS}}
  JSON

private USER_MESSAGE = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"message","user":"U-USER","text":"Summarize this channel","ts":"1729999500.000100",
            "thread_ts":"1729999327.187299","channel":"D-ASSISTANT","channel_type":"im","team":"T-SYNTHETIC",
            "event_ts":"1729999500.000100"},
   "type":"event_callback","event_id":"Ev-MESSAGE","event_time":1729999500,#{AUTHORIZATIONS}}
  JSON

# Another bot's message in the app's direct message: a bot ID and no subtype.
# The app's own messages never reach listeners; see `Slack::App::IgnoreSelf`.
private BOT_MESSAGE = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"message","user":"U-OTHER-BOT","bot_id":"B-OTHER","text":"Here is the summary.",
            "ts":"1729999600.000100","thread_ts":"1729999327.187299","channel":"D-ASSISTANT","channel_type":"im",
            "team":"T-SYNTHETIC","event_ts":"1729999600.000100"},
   "type":"event_callback","event_id":"Ev-BOT","event_time":1729999600,#{AUTHORIZATIONS}}
  JSON

# A user message in a channel, not in the app's direct message.
private CHANNEL_MESSAGE = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"message","user":"U-USER","text":"Summarize this channel","ts":"1729999500.000100",
            "thread_ts":"1729999327.187299","channel":"C-VIEWED","channel_type":"channel","team":"T-SYNTHETIC",
            "event_ts":"1729999500.000100"},
   "type":"event_callback","event_id":"Ev-CHANNEL","event_time":1729999500,#{AUTHORIZATIONS}}
  JSON

# The thread root (subtype `assistant_app_thread`), the user's first message,
# and the app's first reply with the saved context.
private REPLIES = <<-JSON
  {"ok":true,"has_more":false,"messages":[
    {"type":"message","subtype":"assistant_app_thread","user":"U-USER","text":"New chat","ts":"1729999327.187299",
     "thread_ts":"1729999327.187299"},
    {"type":"message","user":"U-USER","text":"Hi","ts":"1729999330.000100","thread_ts":"1729999327.187299"},
    {"type":"message","user":"U-BOT","bot_id":"B-SYNTHETIC","text":"How can I help?","ts":"1729999331.000100",
     "thread_ts":"1729999327.187299",
     "blocks":[{"type":"section","block_id":"greeting","text":{"type":"mrkdwn","text":"How can I help?"}}],
     "metadata":{"event_type":"assistant_thread_context","event_payload":{"channel_id":"C-VIEWED","team_id":"T-SYNTHETIC"}}}]}
  JSON

private REPLIES_WITHOUT_APP_REPLY = <<-JSON
  {"ok":true,"has_more":false,"messages":[
    {"type":"message","subtype":"assistant_app_thread","user":"U-USER","text":"New chat","ts":"1729999327.187299",
     "thread_ts":"1729999327.187299"},
    {"type":"message","user":"U-USER","text":"Hi","ts":"1729999330.000100","thread_ts":"1729999327.187299"}]}
  JSON

private OK     = %({"ok":true})
private POSTED = %({"ok":true,"channel":"D-ASSISTANT","ts":"1729999331.000100","message":{"type":"message","text":"x","ts":"1729999331.000100"}})
private STREAM = %({"ok":true,"channel":"D-ASSISTANT","ts":"1729999501.000100"})

private def assistant_app(transport : Slack::Testing::RecordingTransport) : Slack::App
  client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxb-synthetic-assistant"), transport: transport)
  Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client), response_url_transport: transport)
end

private def receive(app : Slack::App, body : String) : AppSupport::Reply
  AppSupport.run(Slack::App::HttpReceiver.new(app, AppSupport::VERIFIER), AppSupport.json(body))
end

private def methods(transport : Slack::Testing::RecordingTransport) : Array(String)
  transport.requests.map(&.uri.path.lchop("/api/"))
end

private def json_body(request : Slack::Auth::TransportRequest) : JSON::Any
  JSON.parse(request.body || raise "Missing request body")
end

private def form_body(request : Slack::Auth::TransportRequest) : URI::Params
  URI::Params.parse(request.body || raise "Missing request body")
end

# Runs *body* through an app with *assistant* and waits until a handler sends to *done*.
private def deliver(assistant : Slack::App::Assistant, transport : Slack::Testing::RecordingTransport,
                    body : String, done : Channel(T)) : T forall T
  app = assistant_app(transport)
  app.assistant(assistant)
  receive(app, body).status.should eq 200
  select
  when value = done.receive
    value
  when timeout(2.seconds)
    raise "The handler did not finish"
  end
end

describe Slack::App::Assistant do
  it "greets a started thread with the thread context as metadata and sets suggested prompts" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(POSTED).respond(OK)
    assistant = Slack::App::Assistant.new
    done = Channel(Nil).new(1)
    assistant.thread_started do |ctx|
      ctx.say("How can I help?")
      ctx.set_suggested_prompts([Slack::Api::SuggestedPrompt.new("Summarize", "Summarize this channel.")],
        title: "Try one of these")
      done.send(nil)
    end

    deliver(assistant, transport, THREAD_STARTED, done)

    methods(transport).should eq ["chat.postMessage", "assistant.threads.setSuggestedPrompts"]
    requests = transport.requests
    requests.first.headers["Authorization"].should eq "Bearer xoxb-synthetic-assistant"
    json_body(requests[0]).should eq JSON.parse(<<-JSON)
      {"channel":"D-ASSISTANT","text":"How can I help?","thread_ts":"1729999327.187299",
       "metadata":{"event_type":"assistant_thread_context",
                   "event_payload":{"channel_id":"C-VIEWED","team_id":"T-SYNTHETIC","enterprise_id":"E-SYNTHETIC"}}}
      JSON
    json_body(requests[1]).should eq JSON.parse(<<-JSON)
      {"channel_id":"D-ASSISTANT","title":"Try one of these",
       "prompts":[{"title":"Summarize","message":"Summarize this channel."}]}
      JSON
  end

  it "answers a user message with a status and a streamed reply that carries the stored context" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(OK).respond(REPLIES).respond(STREAM).respond(STREAM)
    transport.respond(%({"ok":true,"channel":"D-ASSISTANT","ts":"1729999501.000100","message":{"type":"message","text":"Done."}}))
    assistant = Slack::App::Assistant.new
    done = Channel(String?).new(1)
    assistant.user_message do |ctx|
      ctx.set_status("is thinking...", loading_messages: ["Reading the channel"])
      final = ctx.stream do |stream|
        stream.append(ctx.client, markdown_text: "Done.")
      end
      done.send(final.message.try(&.["text"].as_s))
    end

    deliver(assistant, transport, USER_MESSAGE, done).should eq "Done."

    methods(transport).should eq ["assistant.threads.setStatus", "conversations.replies", "chat.startStream",
                                  "chat.appendStream", "chat.stopStream"]
    requests = transport.requests
    json_body(requests[0]).should eq JSON.parse(<<-JSON)
      {"channel_id":"D-ASSISTANT","thread_ts":"1729999327.187299","status":"is thinking...",
       "loading_messages":["Reading the channel"]}
      JSON
    form_body(requests[1]).should eq URI::Params.parse(
      "channel=D-ASSISTANT&ts=1729999327.187299&include_all_metadata=true&oldest=1729999327.187299&limit=4")
    json_body(requests[2]).should eq JSON.parse(<<-JSON)
      {"channel":"D-ASSISTANT","thread_ts":"1729999327.187299",
       "recipient_user_id":"U-USER","recipient_team_id":"T-SYNTHETIC"}
      JSON
    json_body(requests[3]).should eq JSON.parse(%({"channel":"D-ASSISTANT","ts":"1729999501.000100","markdown_text":"Done."}))
    json_body(requests[4]).should eq JSON.parse(<<-JSON)
      {"channel":"D-ASSISTANT","ts":"1729999501.000100","session_status":"closed",
       "metadata":{"event_type":"assistant_thread_context","event_payload":{"channel_id":"C-VIEWED","team_id":"T-SYNTHETIC"}}}
      JSON
  end

  it "stops a stream with the session status that the handler gives" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(REPLIES_WITHOUT_APP_REPLY).respond(STREAM).respond(STREAM)
    assistant = Slack::App::Assistant.new
    done = Channel(Nil).new(1)
    assistant.user_message do |ctx|
      ctx.stream(session_status: Slack::Api::Streaming::SessionStatus::Active) { }
      done.send(nil)
    end

    deliver(assistant, transport, USER_MESSAGE, done)

    methods(transport).should eq ["conversations.replies", "chat.startStream", "chat.stopStream"]
    json_body(transport.requests[2]).should eq JSON.parse(
      %({"channel":"D-ASSISTANT","ts":"1729999501.000100","session_status":"active"}))
  end

  it "opens no stream when the thread context cannot be read" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":false,"error":"internal_error"}))
    app = assistant_app(transport)
    assistant = Slack::App::Assistant.new
    started = Channel(Bool).new(1)
    assistant.user_message do |ctx|
      ctx.stream { started.send(true) }
    end
    app.assistant(assistant)
    reported = Channel(String).new(1)
    app.error { |error, _ctx| reported.send(error.cause.class.name) }

    receive(app, USER_MESSAGE).status.should eq 200
    reported.receive.should eq "Slack::Api::Error"

    methods(transport).should eq ["conversations.replies"]
    select
    when started.receive
      fail "The stream block ran"
    else
    end
  end

  it "reads the context of a user message from the app's first reply and says without metadata when there is none" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(REPLIES).respond(REPLIES_WITHOUT_APP_REPLY).respond(POSTED)
    assistant = Slack::App::Assistant.new
    done = Channel(String?).new(1)
    assistant.user_message do |ctx|
      viewed = ctx.thread_context.try(&.channel_id)
      ctx.say("No context yet.")
      done.send(viewed)
    end

    deliver(assistant, transport, USER_MESSAGE, done).should eq "C-VIEWED"

    methods(transport).should eq ["conversations.replies", "conversations.replies", "chat.postMessage"]
    json_body(transport.requests[2]).should eq JSON.parse(
      %({"channel":"D-ASSISTANT","text":"No context yet.","thread_ts":"1729999327.187299"}))
  end

  it "saves a changed context on the app's first reply by default and keeps its text and blocks" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(REPLIES).respond(OK)
    done = Channel(Nil).new(1)
    app = assistant_app(transport)
    app.assistant(Slack::App::Assistant.new)
    # Middleware runs around the default handler; it signals after the handler returns.
    app.use do |_ctx, call_next|
      call_next.call
      done.send(nil)
    end

    receive(app, CONTEXT_CHANGED).status.should eq 200
    done.receive

    methods(transport).should eq ["conversations.replies", "chat.update"]
    update = form_body(transport.requests[1])
    update["channel"].should eq "D-ASSISTANT"
    update["ts"].should eq "1729999331.000100"
    update["text"].should eq "How can I help?"
    JSON.parse(update["blocks"]).should eq JSON.parse(
      %([{"type":"section","block_id":"greeting","text":{"type":"mrkdwn","text":"How can I help?"}}]))
    JSON.parse(update["metadata"]).should eq JSON.parse(
      %({"event_type":"assistant_thread_context","event_payload":{"channel_id":"C-OTHER","team_id":"T-SYNTHETIC"}}))
  end

  it "sets the thread title through a custom context store" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(OK).respond(POSTED)
    store = MemoryThreadContextStore.new
    assistant = Slack::App::Assistant.new(context_store: store)
    done = Channel(Nil).new(1)
    assistant.thread_context_changed do |ctx|
      ctx.save_thread_context
      ctx.set_title("Channel summary")
      ctx.say("Switched to the new channel.")
      done.send(nil)
    end

    deliver(assistant, transport, CONTEXT_CHANGED, done)

    store.saved.should eq [{"D-ASSISTANT", "1729999327.187299", "C-OTHER"}]
    methods(transport).should eq ["assistant.threads.setTitle", "chat.postMessage"]
    json_body(transport.requests[0]).should eq JSON.parse(
      %({"channel_id":"D-ASSISTANT","thread_ts":"1729999327.187299","title":"Channel summary"}))
  end

  it "leaves bot messages, channel messages, and subtypes to other listeners" do
    [BOT_MESSAGE, CHANNEL_MESSAGE, USER_MESSAGE.sub(%("type":"message",), %("type":"message","subtype":"me_message",))].each do |body|
      transport = Slack::Testing::RecordingTransport.new
      assistant = Slack::App::Assistant.new
      handled = Channel(String).new(1)
      assistant.user_message { handled.send("assistant") }
      app = assistant_app(transport)
      app.assistant(assistant)
      app.event(Slack::Event) { handled.send("event") }

      receive(app, body).status.should eq 200
      handled.receive.should eq "event"
      transport.requests.should be_empty
    end
  end

  it "passes a handler exception to the app's error handler" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":false,"error":"not_in_channel"}))
    app = assistant_app(transport)
    assistant = Slack::App::Assistant.new
    assistant.thread_started(&.say("Hello"))
    app.assistant(assistant)
    reported = Channel(String).new(1)
    app.error { |error, _ctx| reported.send("#{error.route} #{error.acknowledged?}") }

    receive(app, THREAD_STARTED).status.should eq 200
    reported.receive.should eq "Slack::App::AssistantContext(Slack::Events::AssistantThreadStarted) true"
  end
end

# Keeps saved contexts in memory, to prove that the helper uses the store it gets.
private class MemoryThreadContextStore < Slack::App::Assistant::ThreadContextStore
  getter saved = [] of Tuple(String, String, String?)

  def get(*, client : Slack::Api::Client, channel_id : String, thread_ts : String,
          bot_user_id : String?) : Slack::EventData::AssistantThreadContext?
  end

  def save(*, client : Slack::Api::Client, channel_id : String, thread_ts : String, bot_user_id : String?,
           context : Slack::EventData::AssistantThreadContext) : Nil
    @saved << {channel_id, thread_ts, context.channel_id}
  end
end

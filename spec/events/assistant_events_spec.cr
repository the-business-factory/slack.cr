require "../spec_helper"

private def assistant_event(path : String) : Slack::Event
  envelope = Slack::Events.parse(File.read("spec/fixtures/events/#{path}.json")).should be_a(Slack::VerifiedEvent)
  envelope.event
end

describe "Assistant and agent session events" do
  it "decodes a started assistant thread with the viewed channel context" do
    started = assistant_event("assistant_thread_started").should be_a(Slack::Events::AssistantThreadStarted)
    started.event_ts.should eq "1789232400.000200"

    thread = started.assistant_thread
    thread.user_id.should eq "U-ASKER"
    thread.channel_id.should eq "D-ASSISTANT"
    thread.thread_ts.should eq "1789232400.000100"

    context = thread.context.should_not be_nil
    context.channel_id.should eq "C-VIEWED"
    context.team_id.should eq "T-CONTEXT"
    context.enterprise_id.should eq "E-CONTEXT"
  end

  it "decodes a changed thread context that Slack sends as an empty object" do
    changed = assistant_event("assistant_thread_context_changed").should be_a(Slack::Events::AssistantThreadContextChanged)
    changed.event_ts.should eq "1789232400.000300"
    changed.assistant_thread.channel_id.should eq "D-ASSISTANT"

    context = changed.assistant_thread.context.should_not be_nil
    {context.channel_id, context.team_id, context.enterprise_id}.should eq({nil, nil, nil})
  end

  it "gives a nil context when the thread has none" do
    json = %({"type":"assistant_thread_started","event_ts":"1789232400.000200","assistant_thread":{"user_id":"U-ASKER","channel_id":"D-ASSISTANT","thread_ts":"1789232400.000100"}})
    started = Slack::Event.from_json(json).should be_a(Slack::Events::AssistantThreadStarted)
    started.assistant_thread.context.should be_nil
  end

  it "rejects a thread event without the thread to answer in" do
    json = %({"type":"assistant_thread_started","event_ts":"1789232400.000200","assistant_thread":{"user_id":"U-ASKER","channel_id":"D-ASSISTANT"}})
    expect_raises(JSON::SerializableError, /thread_ts/) { Slack::Event.from_json(json) }
  end

  it "decodes the entities that the user views in relevance order" do
    changed = assistant_event("app_context_changed").should be_a(Slack::Events::AppContextChanged)
    changed.context.entities.map { |item| {item.type, item.value, item.team_id} }
      .should eq [{"slack#/types/channel_id", "C-VIEWED", "T-CONTEXT"}]

    empty = Slack::Event.from_json(%({"type":"app_context_changed","context":{}}))
      .should be_a(Slack::Events::AppContextChanged)
    empty.context.entities.should be_empty
  end

  it "decodes a stopped agent session with the stopped stream timestamps" do
    stopped = assistant_event("agent_session_stopped").should be_a(Slack::Events::AgentSessionStopped)
    stopped.channel.should eq "C-AGENT"
    stopped.user.should eq "U-STOPPER"
    stopped.thread_ts.should eq "1789232400.000100"
    stopped.event_ts.should eq "1789232400.000500"
    stopped.streaming_message_ts.should eq ["1789232400.000400"]

    idle = Slack::Event.from_json(%({"type":"agent_session_stopped","channel":"C-AGENT","user":"U-STOPPER","thread_ts":"1789232400.000100","event_ts":"1789232400.000500","streaming_message_ts":[]}))
      .should be_a(Slack::Events::AgentSessionStopped)
    idle.streaming_message_ts.should be_empty
  end

  it "decodes an agent session title change with and without a previous title" do
    renamed = assistant_event("agent_session_title_changed").should be_a(Slack::Events::AgentSessionTitleChanged)
    renamed.channel.should eq "C-AGENT"
    renamed.user.should eq "U-RENAMER"
    renamed.thread_ts.should eq "1789232400.000100"
    renamed.event_ts.should eq "1789232400.000600"
    renamed.title.should eq "Bora Bora trip prep"
    renamed.previous_title.should eq "Scuba diving research"
    renamed.team_id.should eq "T-SYNTHETIC"
    renamed.enterprise_id.should be_nil

    first = Slack::Event.from_json(%({"type":"agent_session_title_changed","channel":"C-AGENT","user":"U-RENAMER","thread_ts":"1789232400.000100","event_ts":"1789232400.000600","title":"Trip","enterprise_id":"E-ORG"}))
      .should be_a(Slack::Events::AgentSessionTitleChanged)
    first.previous_title.should be_nil
    first.enterprise_id.should eq "E-ORG"
  end

  it "decodes the root message of an assistant thread" do
    root = assistant_event("message/assistant_app_thread").should be_a(Slack::Events::Message::AssistantAppThread)
    root.subtype.should eq "assistant_app_thread"
    root.channel.should eq "D-ASSISTANT"
    root.im?.should be_true
    root.user.should eq "U-ASKER"
    root.text.should eq "New chat"
    thread = root.assistant_app_thread.should_not be_nil
    thread.title.should eq "New chat"
  end

  it "identifies an assistant thread root inside a changed message" do
    changed = assistant_event("message/assistant_app_thread_changed").should be_a(Slack::Events::Message::MessageChanged)
    changed.message.subtype.should eq "assistant_app_thread"
    thread = changed.message.assistant_app_thread.should_not be_nil
    thread.title.should eq "Chats from 2026-09-12T17:00:00.000Z"

    previous = changed.previous_message.should_not be_nil
    previous.subtype.should eq "assistant_app_thread"
  end
end

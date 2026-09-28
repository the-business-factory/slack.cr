require "../spec_helper"
require "../support/api/webmock_client"

private def stub_assistant_method(method : String, expected_body : String, response : String = %({"ok":true})) : Nil
  WebMock.stub(:post, "https://slack.com/api/#{method}")
    .with(headers: {"Authorization" => "Bearer xoxb-synthetic-assistant",
                    "Content-Type"  => "application/json; charset=utf-8"})
    .to_return do |request|
      JSON.parse(request.body || fail("Expected a JSON request body")).should eq JSON.parse(expected_body)
      HTTP::Client::Response.new(200, body: response)
    end
end

private def assistant_client : Slack::Api::Client
  ApiSupport.client(token: "xoxb-synthetic-assistant")
end

private def validation_codes(&) : Array(String)
  error = expect_raises(Slack::UI::ValidationError) { yield }
  error.issues.map(&.code)
end

private def suggested_prompts(count : Int32) : Array(Slack::Api::SuggestedPrompt)
  Array.new(count) { |index| Slack::Api::SuggestedPrompt.new(title: "Prompt #{index}", message: "Message #{index}") }
end

describe Slack::Api::AssistantThreadsSetStatus do
  it "sends the status, loading messages, icon, and username" do
    stub_assistant_method("assistant.threads.setStatus", <<-JSON)
      {"channel_id":"D123","thread_ts":"1724264405.531769","status":"is thinking...",
       "loading_messages":["Reading the thread","Checking the report"],
       "icon_emoji":":robot_face:","username":"Helper"}
      JSON

    request = Slack::Api::AssistantThreadsSetStatus.new(channel_id: "D123", thread_ts: "1724264405.531769",
      status: "is thinking...", loading_messages: ["Reading the thread", "Checking the report"],
      icon: Slack::UI::Icon::Emoji.new(":robot_face:"), username: "Helper")
    assistant_client.call(request).ok?.should be_true
  end

  it "clears the status with an empty status string" do
    stub_assistant_method("assistant.threads.setStatus",
      %({"channel_id":"D123","thread_ts":"1724264405.531769","status":""}))

    request = Slack::Api::AssistantThreadsSetStatus.new(channel_id: "D123", thread_ts: "1724264405.531769", status: "")
    assistant_client.call(request).ok?.should be_true
  end

  it "keeps its loading messages when the caller changes the given array" do
    messages = ["Reading the thread"]
    request = Slack::Api::AssistantThreadsSetStatus.new(channel_id: "D123", thread_ts: "1724264405.531769",
      status: "is thinking...", loading_messages: messages)
    messages << "Changed"
    request.loading_messages.try(&.<<("Changed again"))

    JSON.parse(request.body)["loading_messages"].should eq JSON.parse(%(["Reading the thread"]))
  end

  it "rejects 11 loading messages and an empty list before sending" do
    too_many = Array.new(11) { |index| "Step #{index}" }
    validation_codes do
      assistant_client.call(Slack::Api::AssistantThreadsSetStatus.new(channel_id: "D123",
        thread_ts: "1724264405.531769", status: "is thinking...", loading_messages: too_many))
    end.should eq ["assistant_threads_set_status.loading_messages.too_many"]

    validation_codes do
      assistant_client.call(Slack::Api::AssistantThreadsSetStatus.new(channel_id: "D123",
        thread_ts: "1724264405.531769", status: "is thinking...", loading_messages: [] of String))
    end.should eq ["assistant_threads_set_status.loading_messages.empty"]
  end

  it "rejects a blank channel, a malformed thread timestamp, and a blank username" do
    validation_codes do
      Slack::Api::AssistantThreadsSetStatus.new(channel_id: " ", thread_ts: "latest",
        status: "is thinking...", username: "").validate!
    end.should eq ["assistant_threads_set_status.channel_id.blank",
                   "assistant_threads_set_status.thread_ts.invalid",
                   "assistant_threads_set_status.username.blank"]
  end

  it "raises the Slack error code" do
    stub_assistant_method("assistant.threads.setStatus",
      %({"channel_id":"D123","thread_ts":"1724264405.531769","status":"is thinking..."}),
      %({"ok":false,"error":"invalid_thread_ts"}))

    request = Slack::Api::AssistantThreadsSetStatus.new(channel_id: "D123", thread_ts: "1724264405.531769",
      status: "is thinking...")
    error = expect_raises(Slack::Api::Error) { assistant_client.call(request) }
    error.code.should eq "invalid_thread_ts"
  end
end

describe Slack::Api::AssistantThreadsSetSuggestedPrompts do
  it "sends a titled list of prompts for a thread" do
    stub_assistant_method("assistant.threads.setSuggestedPrompts", <<-JSON)
      {"channel_id":"D123","thread_ts":"1724264405.531769","title":"Try one of these",
       "prompts":[{"title":"Summarize","message":"Summarize this channel."},
                  {"title":"Draft","message":"Draft a status update."}]}
      JSON

    request = Slack::Api::AssistantThreadsSetSuggestedPrompts.new(channel_id: "D123",
      thread_ts: "1724264405.531769", title: "Try one of these",
      prompts: [Slack::Api::SuggestedPrompt.new(title: "Summarize", message: "Summarize this channel."),
                Slack::Api::SuggestedPrompt.new(title: "Draft", message: "Draft a status update.")])
    assistant_client.call(request).ok?.should be_true
  end

  it "sends prompts without a title or thread" do
    stub_assistant_method("assistant.threads.setSuggestedPrompts",
      %({"channel_id":"D123","prompts":[{"title":"Help","message":"What can you do?"}]}))

    request = Slack::Api::AssistantThreadsSetSuggestedPrompts.new(channel_id: "D123",
      prompts: [Slack::Api::SuggestedPrompt.new(title: "Help", message: "What can you do?")])
    assistant_client.call(request).ok?.should be_true
  end

  it "keeps its prompts when the caller changes the given array" do
    prompts = suggested_prompts(1)
    request = Slack::Api::AssistantThreadsSetSuggestedPrompts.new(channel_id: "D123", prompts: prompts)
    prompts << Slack::Api::SuggestedPrompt.new(title: "Late", message: "Added later")
    request.prompts << Slack::Api::SuggestedPrompt.new(title: "Later", message: "Added to the copy")

    JSON.parse(request.body)["prompts"].as_a.size.should eq 1
  end

  it "rejects 5 prompts and an empty list before sending" do
    validation_codes do
      assistant_client.call(Slack::Api::AssistantThreadsSetSuggestedPrompts.new(channel_id: "D123",
        prompts: suggested_prompts(5)))
    end.should eq ["assistant_threads_set_suggested_prompts.prompts.too_many"]

    validation_codes do
      assistant_client.call(Slack::Api::AssistantThreadsSetSuggestedPrompts.new(channel_id: "D123",
        prompts: suggested_prompts(0)))
    end.should eq ["assistant_threads_set_suggested_prompts.prompts.empty"]
  end

  it "rejects a prompt with a blank title or message" do
    validation_codes do
      Slack::Api::SuggestedPrompt.new(title: " ", message: "")
    end.should eq ["suggested_prompt.title.blank", "suggested_prompt.message.blank"]
  end
end

describe Slack::Api::AssistantThreadsSetTitle do
  it "sends the thread title" do
    stub_assistant_method("assistant.threads.setTitle",
      %({"channel_id":"D324567865","thread_ts":"1786543.345678","title":"Holidays this year"}))

    request = Slack::Api::AssistantThreadsSetTitle.new(channel_id: "D324567865", thread_ts: "1786543.345678",
      title: "Holidays this year")
    assistant_client.call(request).ok?.should be_true
  end

  it "rejects a blank title before sending" do
    validation_codes do
      assistant_client.call(Slack::Api::AssistantThreadsSetTitle.new(channel_id: "D123",
        thread_ts: "1786543.345678", title: ""))
    end.should eq ["assistant_threads_set_title.title.blank"]
  end
end

describe Slack::Api::SuggestedPrompt do
  it "sends a prompt read from JSON configuration" do
    stub_assistant_method("assistant.threads.setSuggestedPrompts",
      %({"channel_id":"D123","prompts":[{"title":"Help","message":"What can you do?"}]}))

    prompt = Slack::Api::SuggestedPrompt.from_json(%({"title":"Help","message":"What can you do?"}))
    assistant_client.call(Slack::Api::AssistantThreadsSetSuggestedPrompts.new(channel_id: "D123", prompts: [prompt]))
      .ok?.should be_true
  end

  it "rejects a blank prompt read from JSON before sending" do
    prompt = Slack::Api::SuggestedPrompt.from_json(%({"title":"","message":" "}))
    request = Slack::Api::AssistantThreadsSetSuggestedPrompts.new(channel_id: "D123", prompts: [prompt])

    error = expect_raises(Slack::UI::ValidationError) { assistant_client.call(request) }
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"suggested_prompt.title.blank", "prompts.0.title"},
      {"suggested_prompt.message.blank", "prompts.0.message"},
    ]
    expect_raises(Slack::UI::ValidationError) { prompt.to_json }
  end
end

require "../spec_helper"
require "../support/auth/fakes"
require "log/spec"

private def recording_client(*bodies, status : Int32 = 200,
                             headers : HTTP::Headers = HTTP::Headers.new,
                             token : String? = "xoxb-synthetic-client")
  transport = AuthSupport::RecordingTransport.new
  bodies.each { |body| transport.enqueue(Slack::Auth::TransportResponse.new(status, headers, body)) }
  configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/api/"))
  {Slack::Api::Client.new(token: token, configuration: configuration, transport: transport), transport}
end

private def delete_request : Slack::Api::ChatDelete
  Slack::Api::ChatDelete.new(channel: "C1", ts: "1710000000.000001")
end

describe Slack::Api::Client do
  it "sends a typed request once and returns its response model" do
    client, transport = recording_client(%({"ok":true,"channel":"C1","ts":"1710000000.000001"}))

    deleted = client.call(delete_request)

    deleted.channel.should eq "C1"
    deleted.ts.should eq "1710000000.000001"
    transport.requests.size.should eq 1
    sent = transport.requests.first
    sent.method.should eq "POST"
    sent.uri.to_s.should eq "https://api.example.test/api/chat.delete"
    sent.headers["Authorization"].should eq "Bearer xoxb-synthetic-client"
    sent.headers["Content-Type"].should eq "application/json; charset=utf-8"
    JSON.parse(sent.body.should_not(be_nil)).should eq JSON.parse(%({"channel":"C1","ts":"1710000000.000001"}))
  end

  it "sends any Web API method as form fields and returns the raw JSON" do
    client, transport = recording_client(%({"ok":true,"emoji":{"wave":"https://emoji.example/wave.png"}}))

    raw = client.call("emoji.list", {include_categories: true, cursor: nil, name: "wave+hand",
                                     blocks: [{type: "divider"}]})

    raw["emoji"]["wave"].as_s.should eq "https://emoji.example/wave.png"
    sent = transport.requests.first
    sent.uri.to_s.should eq "https://api.example.test/api/emoji.list"
    sent.headers["Content-Type"].should eq "application/x-www-form-urlencoded"
    URI::Params.parse(sent.body.should_not(be_nil)).should eq URI::Params.parse(
      "include_categories=true&name=wave%2Bhand&blocks=%5B%7B%22type%22%3A%22divider%22%7D%5D")
  end

  it "accepts string-keyed hashes for the generic call" do
    client, transport = recording_client(%({"ok":true}))

    client.call("apps.uninstall", {"client_id" => "123.456"})["ok"].as_bool.should be_true
    transport.requests.first.body.should eq "client_id=123.456"
  end

  it "sends parsed JSON arguments with the same wire values as native values" do
    client, transport = recording_client(%({"ok":true}))
    params = JSON.parse(%({"channel":"C123","include_num_members":true,"cursor":null,"blocks":[{"type":"divider"}]})).as_h

    client.call("conversations.info", params)

    URI::Params.parse(transport.requests.first.body.should_not(be_nil)).should eq URI::Params.parse(
      "channel=C123&include_num_members=true&blocks=%5B%7B%22type%22%3A%22divider%22%7D%5D")
  end

  it "raises Api::Error with the Slack code and response metadata messages" do
    client, _transport = recording_client(<<-JSON)
      {"ok":false,"error":"invalid_arguments","detail":"canary-body",
       "response_metadata":{"messages":["[ERROR] invalid `trigger_id`"]}}
      JSON

    error = expect_raises(Slack::Api::Error, "invalid_arguments") { client.call(delete_request) }

    error.code.should eq "invalid_arguments"
    error.http_status.should eq 200
    error.retry_after.should be_nil
    error.messages.should eq ["[ERROR] invalid `trigger_id`"]
    error.details.should be_empty
    error.message.to_s.should_not contain("canary")
    error.message.to_s.should_not contain("trigger_id")
    error.message.to_s.should_not contain("xoxb")
  end

  it "keeps the Slack code when the errors array has entries without a message" do
    client, _transport = recording_client(<<-JSON)
      {"ok":false,"error":"cant_invite","errors":[{"user":"U1","ok":false,"error":"cant_invite_self"},"x"]}
      JSON

    error = expect_raises(Slack::Api::Error) { client.call(delete_request) }

    error.code.should eq "cant_invite"
    error.details.should be_empty
  end

  it "logs warnings of a response whose model is a nested object" do
    client, _transport = recording_client(<<-JSON)
      {"ok":true,"warning":"already_in_channel","response_metadata":{"warnings":["already_in_channel","superfluous_charset"]},
       "channel":{"id":"C1","name":"general","is_channel":true,"is_group":false,"is_im":false,"created":1449252889,
       "creator":"U1","is_archived":false,"is_general":true,"name_normalized":"general","is_member":true,
       "is_private":false,"is_mpim":false,"topic":{"value":"","creator":"","last_set":0},
       "purpose":{"value":"","creator":"","last_set":0},"previous_names":[]}}
      JSON

    Log.capture("slack.api") do |logs|
      client.call(Slack::Api::ConversationsJoin.new("C1")).id.should eq "C1"
      logs.check(:warn, "conversations.join returned warnings: already_in_channel, superfluous_charset")
    end
  end

  it "reads the envelope of a raw JSON response" do
    client, _transport = recording_client(%({"ok":false,"error":"channel_not_found"}), %("canary"))

    expect_raises(Slack::Api::Error) { client.call("conversations.info") }.code.should eq "channel_not_found"
    expect_raises(Slack::Api::Error) { client.call("conversations.info") }.code.should eq "invalid_response"
  end

  it "maps HTTP 429 to RateLimited with Retry-After and without reading the body" do
    client, _transport = recording_client("canary-body", status: 429,
      headers: HTTP::Headers{"Retry-After" => "30"})

    error = expect_raises(Slack::Api::RateLimited) { client.call(delete_request) }

    error.code.should eq "ratelimited"
    error.http_status.should eq 429
    error.retry_after.should eq 30.seconds
    error.message.to_s.should_not contain("canary")
  end

  it "ignores an unusable Retry-After value" do
    client, _transport = recording_client("", status: 429, headers: HTTP::Headers{"Retry-After" => "-5"})

    expect_raises(Slack::Api::RateLimited) { client.call(delete_request) }.retry_after.should be_nil
  end

  it "rejects malformed bodies and unexpected model data as invalid responses" do
    {"{canary", %("canary"), %({"ok":"true"}), %({"ok":true,"channel":17,"ts":"1.1"})}.each do |body|
      client, _transport = recording_client(body)
      error = expect_raises(Slack::Api::Error) { client.call(delete_request) }
      error.code.should eq "invalid_response"
      error.message.to_s.should_not contain("canary")
    end
  end

  it "reports a model value that cannot be converted as an invalid response" do
    body = JSON.parse(File.read("spec/fixtures/api/conversations-info-C032TLM43GA.json"))
    body["channel"].as_h["last_read"] = JSON::Any.new("canary-malformed-timestamp")
    client, _transport = recording_client(body.to_json)

    error = expect_raises(Slack::Api::Error) { client.call(Slack::Api::ConversationsInfo.new("C032TLM43GA")) }

    error.code.should eq "invalid_response"
    error.http_status.should eq 200
    error.cause.should be_nil
    error.message.to_s.should_not contain("canary")
    error.inspect.should_not contain("canary")
  end

  it "reports a non-success status without a Slack error envelope as an HTTP error" do
    client, _transport = recording_client("<h1>canary</h1>", status: 503)

    error = expect_raises(Slack::Api::Error) { client.call(delete_request) }

    error.code.should eq "http_error"
    error.http_status.should eq 503
  end

  it "keeps a Slack error code from a non-success status" do
    client, _transport = recording_client(%({"ok":false,"error":"fatal_error"}), status: 500)

    expect_raises(Slack::Api::Error) { client.call(delete_request) }.code.should eq "fatal_error"
  end

  it "rejects invalid local values before the transport or limiter is used" do
    client, transport = recording_client
    message = Slack::UI.message(fallback_text: "Details", &.divider)

    expect_raises(Slack::UI::ValidationError) do
      client.call(Slack::Api::ChatPostMessage.new(channel: "", message: message))
    end
    transport.requests.should be_empty
  end

  it "sends no Authorization header without a token so a scoped transport can add one" do
    client, transport = recording_client(%({"ok":true,"channel":"C1","ts":"1.1"}), token: nil)

    client.call(delete_request)

    transport.requests.first.headers["Authorization"]?.should be_nil
  end

  it "rejects blank tokens and redacts the token from inspect" do
    expect_raises(ArgumentError, "must not be blank") { Slack::Api::Client.new(token: " \t") }
    expect_raises(ArgumentError, "must not be blank") do
      Slack::Api::Client.new(token: Slack::Auth::Secret.new(" "))
    end

    client = Slack::Api::Client.new(token: "xoxb-canary-token")
    client.inspect.should_not contain("canary")
    client.to_s.should_not contain("canary")
  end

  it "passes transport failures through unchanged" do
    client, _transport = recording_client

    expect_raises(Slack::Auth::ContractError, "TransportFailure") { client.call(delete_request) }
  end
end

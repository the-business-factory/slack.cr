require "../spec_helper"

# Counts the JSON texts that the stdlib parsers start on, so a spec can check
# that `Response` parses a body once. The count is off outside `counting`.
class JSON::PullParser
  class_property parsed_texts : Array(String)? = nil

  def initialize(input)
    if input.is_a?(String)
      JSON::PullParser.parsed_texts.try(&.<< input)
    end
    previous_def
  end
end

class JSON::Parser
  def initialize(string_or_io : String | IO)
    if string_or_io.is_a?(String)
      JSON::PullParser.parsed_texts.try(&.<< string_or_io)
    end
    previous_def
  end
end

module ResponseSpec
  def self.counting(&) : Array(String)
    texts = [] of String
    JSON::PullParser.parsed_texts = texts
    begin
      yield
    ensure
      JSON::PullParser.parsed_texts = nil
    end
    texts
  end

  def self.response(body : String, status : Int32 = 200) : Slack::Auth::TransportResponse
    Slack::Auth::TransportResponse.new(status, HTTP::Headers.new, body)
  end

  def self.error(body : String, type : T.class, status : Int32 = 200) : Slack::Api::Error forall T
    expect_raises(Slack::Api::Error) { Slack::Api::Response(T).parse(response(body, status)) }
  end

  # Sends an `ok: false` body with *data* before and after the envelope, at
  # HTTP 200 and 500, and expects Slack's error code and messages.
  def self.keeps_slack_error(type : T.class, data : String) : Nil forall T
    envelope = %("ok":false,"error":"fatal_error","response_metadata":{"messages":["[ERROR] canary-detail"]})
    [%({#{envelope},#{data}}), %({#{data},#{envelope}})].each do |body|
      {200, 500}.each do |status|
        error = error(body, type, status)
        {error.code, error.http_status, error.messages}.should eq({"fatal_error", status, ["[ERROR] canary-detail"]})
      end
    end
  end

  def self.redacted_invalid_response(type : T.class, body : String) : Nil forall T
    error = error(body, type)
    error.code.should eq "invalid_response"
    error.cause.should be_nil
    error.message.to_s.should_not contain("canary")
    error.inspect.should_not contain("canary")
  end

  def self.error_code(body : String, type : T.class, status : Int32 = 200) : String forall T
    error(body, type, status).code
  end
end

describe Slack::Api::Response do
  it "parses a success body once and an error body that does not match the model twice" do
    success = %({"ok":true,"channel":"C1","ts":"1.1"})
    ResponseSpec.counting do
      Slack::Api::Response(Slack::Models::Chat::Delete).parse(ResponseSpec.response(success)).model.channel.should eq "C1"
    end.should eq [success]

    # The model attempt fails without `channel` and `ts`; the envelope is then parsed alone.
    failure = %({"ok":false,"error":"channel_not_found"})
    ResponseSpec.counting do
      ResponseSpec.error_code(failure, Slack::Models::Chat::Delete).should eq "channel_not_found"
    end.should eq [failure, failure]

    outcome = %({"ok":false,"not_in_channel":true})
    ResponseSpec.counting do
      Slack::Api::Response(Slack::Models::Conversations::LeaveResponse).parse(ResponseSpec.response(outcome))
        .model.not_in_channel?.should be_true
    end.should eq [outcome]

    raw = %({"ok":false,"error":"channel_not_found","response_metadata":{"messages":["[ERROR] no channel"]}})
    ResponseSpec.counting do
      expect_raises(Slack::Api::Error) { Slack::Api::Response(JSON::Any).parse(ResponseSpec.response(raw)) }
        .messages.should eq ["[ERROR] no channel"]
    end.should eq [raw]
  end

  it "reads the Slack error from an error body for every typed request" do
    body = %({"ok":false,"error":"channel_not_found"})
    {% begin %}
      {% models = [] of TypeNode %}
      {% for request in Slack::Api::Request.all_subclasses %}
        {% model = request.superclass.type_vars.first %}
        {% models << model unless request.abstract? || model.is_a?(TypeParameter) || models.includes?(model) %}
      {% end %}
      {% for model in models %}
        ResponseSpec.error_code(body, {{ model }}).should eq "channel_not_found"
      {% end %}
    {% end %}
  end

  it "keeps the Slack error of an error body with model data that does not decode" do
    ResponseSpec.keeps_slack_error(Slack::Models::Chat::Delete, %("channel":17))
    ResponseSpec.keeps_slack_error(Slack::Models::Team, %("team":{}))
    ResponseSpec.keeps_slack_error(Slack::Models::ConversationsHistory, %("messages":[{}]))
    ResponseSpec.keeps_slack_error(Slack::Models::Chat::ScheduleMessage, %("post_at":"canary-non-numeric"))
  end

  it "reports malformed model data in a success body as invalid_response without the remote value" do
    ResponseSpec.redacted_invalid_response(Slack::Models::Chat::Delete, %({"ok":true,"channel":17,"ts":"1.1"}))
    ResponseSpec.redacted_invalid_response(Slack::Models::Chat::ScheduleMessage,
      %({"ok":true,"channel":"C1","scheduled_message_id":"Q1","post_at":"canary-non-numeric","message":{}}))
  end

  it "rejects a success without the model's required fields or with a wrong envelope type" do
    ResponseSpec.error_code(%({"ok":true}), Slack::Models::Chat::Delete).should eq "invalid_response"
    ResponseSpec.error_code(%({"ok":true}), Slack::Models::Conversation).should eq "invalid_response"
    ResponseSpec.error_code(%({"ok":true,"error":5}), JSON::Any).should eq "invalid_response"
    ResponseSpec.error_code(%({"ok":true,"response_metadata":{"warnings":[1]}}), JSON::Any)
      .should eq "invalid_response"
    ResponseSpec.error_code(%({"ok":false,"error":"fatal_error"}), Slack::Models::Team, 500).should eq "fatal_error"
  end
end

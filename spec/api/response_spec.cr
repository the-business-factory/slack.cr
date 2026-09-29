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

  def self.error_code(body : String, type : T.class, status : Int32 = 200) : String forall T
    expect_raises(Slack::Api::Error) { Slack::Api::Response(T).parse(response(body, status)) }.code
  end
end

describe Slack::Api::Response do
  it "parses a success, an error body without model fields, and a flagged outcome once each" do
    success = %({"ok":true,"channel":"C1","ts":"1.1"})
    ResponseSpec.counting do
      Slack::Api::Response(Slack::Models::Chat::Delete).parse(ResponseSpec.response(success)).model.channel.should eq "C1"
    end.should eq [success]

    [%({"ok":false,"error":"channel_not_found"}), %({"error":"channel_not_found","ok":false})].each do |failure|
      ResponseSpec.counting do
        ResponseSpec.error_code(failure, Slack::Models::Chat::Delete).should eq "channel_not_found"
      end.should eq [failure]
    end

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
      {{ models.size }}.should be > 40
    {% end %}
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

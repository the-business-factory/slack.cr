require "../spec_helper"

private class RecordingTransport < Slack::Auth::Transport
  getter requests = [] of Slack::Auth::TransportRequest

  def initialize(@status : Int32 = 200, @body : String = "ok")
  end

  def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
    @requests << request
    Slack::Auth::TransportResponse.new(@status, HTTP::Headers{"Content-Type" => "text/html"}, @body)
  end
end

private URL = "https://hooks.slack.com/commands/T-SYNTHETIC/1234/synthetic-secret"

describe Slack::Interactions::ResponseUrlResponder do
  it "posts the message as JSON to the exact response_url" do
    transport = RecordingTransport.new
    responder = Slack::Interactions::ResponseUrlResponder.new(URL)

    responder.post(transport, Slack::Interactions::ResponseUrlMessage.new(text: "Queued."))

    request = transport.requests.first
    transport.requests.size.should eq 1
    request.method.should eq "POST"
    request.uri.to_s.should eq URL
    request.headers["Content-Type"].should eq "application/json"
    request.headers.has_key?("Authorization").should be_false
    JSON.parse(request.body.should_not(be_nil)).should eq(JSON.parse(%({"text":"Queued."})))
  end

  it "raises the HTTP status without the URL or body when Slack rejects the post" do
    transport = RecordingTransport.new(404, "expired_url")
    responder = Slack::Interactions::ResponseUrlResponder.new(URL)

    error = expect_raises(Slack::Interactions::ResponseUrlError) do
      responder.post(transport, Slack::Interactions::ResponseUrlMessage.delete_original)
    end
    error.http_status.should eq 404
    message = error.message.should_not(be_nil)
    message.should_not contain("synthetic-secret")
    message.should_not contain("expired_url")
    responder.inspect.should_not contain("synthetic-secret")
  end

  it "keeps transport failures classified" do
    responder = Slack::Interactions::ResponseUrlResponder.new(URL)
    transport = FailingTransport.new

    error = expect_raises(Slack::Auth::ContractError) do
      responder.post(transport, Slack::Interactions::ResponseUrlMessage.new(text: "Queued."))
    end
    error.code.should eq Slack::Auth::ErrorCode::UnknownRemoteOutcome
  end

  it "rejects a response_url that is not HTTPS" do
    error = expect_raises(Slack::Auth::ContractError) do
      Slack::Interactions::ResponseUrlResponder.new("http://hooks.slack.com/commands/T/1/x")
    end
    error.code.should eq Slack::Auth::ErrorCode::InvalidConfiguration
  end
end

private class FailingTransport < Slack::Auth::Transport
  def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
    raise Slack::Auth::ContractError.new(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
  end
end

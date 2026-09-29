require "../../../examples/support/webmock_transport"

module ApiSupport
  OK = %({"ok":true})

  # A Web API client whose requests reach WebMock stubs at https://slack.com/api/.
  def self.client(token : String = "xoxb-synthetic") : Slack::Api::Client
    Slack::Api::Client.new(token: token, transport: OfflineExample::WebMockTransport.new)
  end

  # Stubs *method* to expect the default client token and the form fields in
  # *form*, in any order, and to answer with *response*.
  def self.stub_form(method : String, form : String, response : String = OK) : Nil
    WebMock.stub(:post, "https://slack.com/api/#{method}")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                      "Content-Type"  => "application/x-www-form-urlencoded"})
      .to_return do |request|
        URI::Params.parse(request.body.to_s).should eq URI::Params.parse(form)
        HTTP::Client::Response.new(200, body: response)
      end
  end

  # Stubs *method* to expect the default client token and a JSON body equal to
  # *expected*, and to answer with *response*.
  def self.stub_json(method : String, expected : String, response : String = OK) : Nil
    WebMock.stub(:post, "https://slack.com/api/#{method}")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                      "Content-Type"  => "application/json; charset=utf-8"})
      .to_return do |request|
        JSON.parse(request.body || fail("Expected a JSON request body")).should eq JSON.parse(expected)
        HTTP::Client::Response.new(200, body: response)
      end
  end
end

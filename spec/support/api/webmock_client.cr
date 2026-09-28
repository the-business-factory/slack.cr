require "../../../examples/support/webmock_transport"

module ApiSupport
  # A Web API client whose requests reach WebMock stubs at https://slack.com/api/.
  def self.client(token : String = "xoxb-synthetic") : Slack::Api::Client
    Slack::Api::Client.new(token: token, transport: OfflineExample::WebMockTransport.new)
  end
end

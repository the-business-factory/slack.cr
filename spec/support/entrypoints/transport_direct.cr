require "slack/auth/http_transport_factory"

factory = Slack::Auth::HTTPTransportFactory.new
transport = factory.build(Slack::Auth::TransportOptions.new)
raise "Unexpected concrete transport" unless transport.is_a?(Slack::Auth::HTTPTransport)

configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/prefix"))
unless configuration.endpoint("team.info").to_s == "https://api.example.test/prefix/team.info"
  raise "Unexpected endpoint"
end

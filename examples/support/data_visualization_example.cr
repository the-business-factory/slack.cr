require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Builds a pie chart and a line chart from application records and posts them.
# Slack permits at most two data visualization blocks in one message.
module OfflineDataVisualizationExample
  alias UI = Slack::UI::Checked
  alias DV = UI::DataVisualization

  record Deploy, service : String, count : Int32
  record Latency, region : String, day : String, milliseconds : Float64

  DAYS    = {"Mon", "Tue", "Wed"}
  DEPLOYS = [Deploy.new("api", 14), Deploy.new("web", 9), Deploy.new("worker", 3)]
  LATENCY = [
    Latency.new("us-east", "Mon", 120.5), Latency.new("us-east", "Tue", 98.0), Latency.new("us-east", "Wed", 101.25),
    Latency.new("eu-west", "Mon", 140.0), Latency.new("eu-west", "Tue", 133.5), Latency.new("eu-west", "Wed", 150.0),
  ]

  # Returns the JSON body that the stubbed chat.postMessage endpoint received.
  def self.run(output : IO = STDOUT) : JSON::Any
    posted : JSON::Any? = nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      posted = JSON.parse(request.body || raise "Missing posted message")
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000400","message":{"text":"Weekly deploy report"}}))
    end

    message = UI.message(fallback_text: "Weekly deploy report") do |builder|
      builder.data_visualization("Deploys by service", block_id: "deploys", chart: DV::PieChart.new(
        DEPLOYS.map { |deploy| DV::Segment.new(deploy.service, deploy.count) }
      ))
      builder.data_visualization("p95 latency", latency_chart(LATENCY))
    end
    result = Slack::Api::CheckedChatPostMessage.new(token: "xoxb-synthetic-chart", channel: "C-SYNTHETIC",
      message: message, transport: OfflineExample::WebMockTransport.new).call
    output.puts "Posted #{DEPLOYS.size} services and #{LATENCY.size} latency points to #{result.channel}/#{result.ts}"

    begin
      latency_chart(LATENCY.reject { |sample| sample.region == "eu-west" && sample.day == "Tue" })
    rescue error : UI::ValidationError
      output.puts "Rejected before sending: #{error.issues.map(&.code).join(", ")}"
    end
    body = posted
    raise "chat.postMessage was not called" unless body
    body
  end

  # Each series needs exactly one point for each category.
  def self.latency_chart(samples : Array(Latency)) : DV::LineChart
    series = samples.group_by(&.region).map do |region, points|
      DV::DataSeries.new(region, points.map { |sample| DV::DataPoint.new(sample.day, sample.milliseconds) })
    end
    DV::LineChart.new(series, DV::AxisConfig.new(DAYS, x_label: "Day", y_label: "Latency (ms)"))
  end
end

require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Opens a deploy status modal with one alert for each check result. Slack shows
# alert blocks in modals only; messages and Home tabs reject them at compile time.
module OfflineAlertExample
  alias UI = Slack::UI::Checked

  record Check, name : String, passed : Bool

  CHECKS = [Check.new("Build", true), Check.new("Migrations", false)]

  # Returns the JSON body that the stubbed views.open endpoint received.
  def self.run(output : IO = STDOUT) : JSON::Any
    opened : JSON::Any? = nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      opened = JSON.parse(request.body || raise "Missing views.open body")
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V-ALERT","type":"modal"}}))
    end

    modal = UI.display_modal(title: UI.plain("Deploy 42"), close: UI.plain("Done")) do |builder|
      CHECKS.each do |check|
        level = check.passed ? UI::Blocks::AlertLevel::Success : UI::Blocks::AlertLevel::Error
        builder.alert(UI.mrkdwn("*#{check.name}* #{check.passed ? "passed" : "failed"}"), level: level, block_id: "check.#{check.name.downcase}")
      end
      builder.section(UI.plain("Fix the failed checks, then deploy again."))
    end
    Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic-alert", trigger_id: "synthetic-trigger",
      view: modal, transport: OfflineExample::WebMockTransport.new).call
    output.puts "Opened deploy status with #{CHECKS.size} alerts"

    begin
      UI::Blocks::Alert.new(UI.plain("x" * 201))
    rescue error : UI::ValidationError
      output.puts "Rejected before sending: #{error.issues.map(&.code).join(", ")}"
    end
    body = opened
    raise "views.open was not called" unless body
    body
  end
end

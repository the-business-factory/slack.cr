require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Adds a remote file, shares it to a channel, and builds a remote file block for
# an application's own `chat.unfurl` request. Slack does not let apps add file
# blocks to messages directly: `files.remote.share` shows the file in a channel.
module OfflineRemoteFileExample
  alias UI = Slack::UI

  LINK = "https://docs.example.test/plans/2026-q4"

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    client = Slack::Api::Client.new(token: "xoxb-synthetic-remote-file", transport: OfflineExample::WebMockTransport.new)
    stub_slack

    added = client.call(Slack::Api::FilesRemoteAdd.new(external_id: "plan-2026-q4", external_url: LINK,
      title: "Q4 plan")).file
    output.puts "Added remote file #{added.id}"
    target = Slack::Api::RemoteFileTarget.external_id("plan-2026-q4")
    client.call(Slack::Api::FilesRemoteShare.new(target, channels: ["C123"]))
    output.puts "Shared plan-2026-q4 to C123"

    file = UI::Blocks::File.new(external_id: "plan-2026-q4", block_id: "plan.file")
    unfurls = JSON.build do |json|
      json.object do
        json.field LINK do
          json.object do
            json.field "blocks", {file}
          end
        end
      end
    end
    output.puts unfurls
  end

  private def self.stub_slack : Nil
    WebMock.stub(:post, "https://slack.com/api/files.remote.add")
      .with(body: "external_id=plan-2026-q4&external_url=https%3A%2F%2Fdocs.example.test%2Fplans%2F2026-q4&title=Q4+plan")
      .to_return(body: %({"ok":true,"file":{"id":"F08EAQ813FW","title":"Q4 plan","external_id":"plan-2026-q4"}}))
    WebMock.stub(:post, "https://slack.com/api/files.remote.share")
      .with(body: "external_id=plan-2026-q4&channels=C123")
      .to_return(body: %({"ok":true,"file":{"id":"F08EAQ813FW"}}))
  end
end

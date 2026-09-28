require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Uploads an in-memory text file with the three-step flow and shares it to a channel.
module OfflineFileUploadExample
  UPLOAD_URL = "https://files.slack.com/upload/v1/synthetic-upload"

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    transport = OfflineExample::WebMockTransport.new
    client = Slack::Api::Client.new(token: "xoxb-synthetic-files", transport: transport)
    stub_slack

    upload = Slack::Api::FileUpload.new("release-notes.txt", IO::Memory.new("Version 1.2 is ready.\n"),
      title: "Release notes",
      share: Slack::Api::FileShare.new(channel_id: "C123", initial_comment: "Release notes for 1.2"))
    # The byte upload goes to files.slack.com without a token, so it uses the raw transport.
    files = upload.run(client, transport)
    files.each { |file| output.puts "Uploaded #{file.id} (#{file.title}) to C123" }
  end

  private def self.stub_slack : Nil
    WebMock.stub(:post, "https://slack.com/api/files.getUploadURLExternal")
      .with(body: "filename=release-notes.txt&length=22")
      .to_return(body: %({"ok":true,"upload_url":"#{UPLOAD_URL}","file_id":"F123"}))
    WebMock.stub(:post, UPLOAD_URL)
      .with(body: "Version 1.2 is ready.\n", headers: {"Content-Type" => "application/octet-stream"})
      .to_return(body: "OK - 22")
    WebMock.stub(:post, "https://slack.com/api/files.completeUploadExternal")
      .to_return(body: %({"ok":true,"files":[{"id":"F123","title":"Release notes"}]}))
  end
end

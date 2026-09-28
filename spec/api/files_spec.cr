require "../spec_helper"
require "../support/api/webmock_client"

private UPLOAD_URL = "https://files.slack.com/upload/v1/CwABAAAAXAoAAZnKg"

private def stub_upload_url(expected_form : String) : Nil
  WebMock.stub(:post, "https://slack.com/api/files.getUploadURLExternal")
    .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                    "Content-Type"  => "application/x-www-form-urlencoded"})
    .to_return do |request|
      URI::Params.parse(request.body.to_s).should eq URI::Params.parse(expected_form)
      HTTP::Client::Response.new(200, body: %({"ok":true,"upload_url":"#{UPLOAD_URL}","file_id":"F0AB1CD2EF3"}))
    end
end

private def form_body(request : HTTP::Request) : URI::Params
  URI::Params.parse(request.body.to_s)
end

describe Slack::Api::FileUpload do
  it "gets an upload URL, posts the bytes without a token, and completes the upload" do
    stub_upload_url("filename=notes.txt&length=11&alt_txt=Release+notes")
    WebMock.stub(:post, UPLOAD_URL).to_return do |request|
      request.headers["Content-Type"].should eq "application/octet-stream"
      request.headers["Authorization"]?.should be_nil
      request.body.to_s.should eq "hello\x00world"
      HTTP::Client::Response.new(200, body: "OK - 11")
    end
    WebMock.stub(:post, "https://slack.com/api/files.completeUploadExternal")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic"})
      .to_return do |request|
        form = form_body(request)
        JSON.parse(form["files"]).should eq JSON.parse(%([{"id":"F0AB1CD2EF3","title":"Release notes"}]))
        form["channel_id"].should eq "C0123456789"
        form["initial_comment"].should eq "Notes for 1.2"
        form.has_key?("blocks").should be_false
        HTTP::Client::Response.new(200, body: <<-JSON)
          {"ok":true,"files":[{"id":"F0AB1CD2EF3","name":"notes.txt","title":"Release notes",
            "mimetype":"text/plain","filetype":"text","size":11,"user":"U0123456789","created":1727500000,
            "url_private":"https://files.slack.com/files-pri/T1-F0AB1CD2EF3/notes.txt",
            "permalink":"https://example.slack.com/files/U0123456789/F0AB1CD2EF3/notes.txt",
            "shares":{"public":{"C0123456789":[{"ts":"1727500001.000100"}]}}}]}
          JSON
      end

    upload = Slack::Api::FileUpload.new("notes.txt", IO::Memory.new("hello\x00world"),
      title: "Release notes", alt_txt: "Release notes",
      share: Slack::Api::FileShare.new(channel_id: "C0123456789", initial_comment: "Notes for 1.2"))
    files = upload.run(ApiSupport.client, AuthSupport::WebMockTransport.new)

    file = files.first
    file.id.should eq "F0AB1CD2EF3"
    file.size.should eq 11
    file.created.should eq 1727500000
    file.permalink.should eq "https://example.slack.com/files/U0123456789/F0AB1CD2EF3/notes.txt"
    shares = file.shares.should_not be_nil
    shares["public"]["C0123456789"][0]["ts"].should eq "1727500001.000100"
  end

  it "raises the HTTP status of a failed byte upload and does not complete it" do
    stub_upload_url("filename=report.csv&length=3")
    WebMock.stub(:post, UPLOAD_URL).to_return(status: 500, body: "upload failed")
    completed = false
    WebMock.stub(:post, "https://slack.com/api/files.completeUploadExternal").to_return do
      completed = true
      HTTP::Client::Response.new(200, body: %({"ok":true,"files":[]}))
    end

    error = expect_raises(Slack::Api::Error, "http_error") do
      Slack::Api::FileUpload.new("report.csv", "a,b".to_slice)
        .run(ApiSupport.client, AuthSupport::WebMockTransport.new)
    end
    error.http_status.should eq 500
    completed.should be_false
  end

  it "does not send bytes to an upload URL that is not HTTPS" do
    WebMock.stub(:post, "https://slack.com/api/files.getUploadURLExternal")
      .to_return(body: %({"ok":true,"upload_url":"http://files.slack.com/upload","file_id":"F1"}))

    error = expect_raises(Slack::Api::Error, "invalid_response") do
      Slack::Api::FileUpload.new("a.txt", "a".to_slice).run(ApiSupport.client, AuthSupport::WebMockTransport.new)
    end
    error.http_status.should eq 200
  end

  it "validates the upload and its share before any request" do
    blocks = Slack::UI.message_with_slack_generated_fallback { |message| message.section(Slack::UI.mrkdwn("Notes")) }
    upload = Slack::Api::FileUpload.new("notes.txt", "x".to_slice, alt_txt: "a" * 1001,
      share: Slack::Api::FileShare.new(channel_id: "C1", initial_comment: "Notes", blocks: blocks))

    error = expect_raises(Slack::UI::ValidationError) do
      upload.run(ApiSupport.client, AuthSupport::WebMockTransport.new)
    end
    error.issues.map(&.code).should eq %w[files_get_upload_url_external.alt_txt.too_long
      file_share.blocks.with_initial_comment]
  end
end

describe Slack::Api::FilesCompleteUploadExternal do
  it "shares several files to channels in a thread with blocks and a custom icon" do
    WebMock.stub(:post, "https://slack.com/api/files.completeUploadExternal")
      .with(headers: {"Content-Type" => "application/x-www-form-urlencoded"})
      .to_return do |request|
        form = form_body(request)
        JSON.parse(form["files"]).should eq JSON.parse(%([{"id":"F1"},{"id":"F2","title":"Second"}]))
        form["channels"].should eq "C1"
        form["thread_ts"].should eq "1727500001.000100"
        JSON.parse(form["blocks"]).should eq JSON.parse(
          %([{"type":"section","text":{"type":"mrkdwn","text":"Two files"}}]))
        form["username"].should eq "Release bot"
        form["icon_emoji"].should eq ":package:"
        HTTP::Client::Response.new(200, body: %({"ok":true,"files":[{"id":"F1","title":"F1"},{"id":"F2","title":"Second"}]}))
      end

    blocks = Slack::UI.message_with_slack_generated_fallback { |message| message.section(Slack::UI.mrkdwn("Two files")) }
    share = Slack::Api::FileShare.new(channels: ["C1"], thread_ts: "1727500001.000100", blocks: blocks,
      username: "Release bot", icon_emoji: ":package:")
    request = Slack::Api::FilesCompleteUploadExternal.new(
      [Slack::Api::FileReference.new("F1"), Slack::Api::FileReference.new("F2", title: "Second")], share)

    ApiSupport.client.call(request).files.map(&.title).should eq ["F1", "Second"]
  end

  it "keeps the files and channels given at construction" do
    channels = ["C1"]
    files = [Slack::Api::FileReference.new("F1")]
    share = Slack::Api::FileShare.new(channels: channels)
    request = Slack::Api::FilesCompleteUploadExternal.new(files, share)
    remote = Slack::Api::FilesRemoteShare.new(Slack::Api::RemoteFileTarget.file("F1"), channels: channels)

    channels[0] = "C_REPLACEMENT"
    files[0] = Slack::Api::FileReference.new("F_REPLACEMENT")
    share.channels.try(&.<<("C_GETTER"))
    request.files << Slack::Api::FileReference.new("F_GETTER")
    remote.channels << "C_GETTER"

    request.form.should eq URI::Params{"files" => %([{"id":"F1"}]), "channels" => "C1"}
    remote.form.should eq URI::Params{"file" => "F1", "channels" => "C1"}
  end

  it "rejects conflicting and oversized share fields" do
    share = Slack::Api::FileShare.new(channel_id: "C1", channels: (1..101).map { |index| "C#{index}" },
      thread_ts: "1727500001.000100", icon_emoji: ":package:", icon_url: "https://example.test/icon.png")
    request = Slack::Api::FilesCompleteUploadExternal.new([] of Slack::Api::FileReference, share)

    request.validate.map(&.code).should eq %w[files_complete_upload_external.files.empty
      file_share.channels.too_many file_share.channel.conflict file_share.thread_ts.single_channel_required
      file_share.icon.conflict]
  end
end

describe Slack::Api::FilesInfo do
  it "reads one file" do
    WebMock.stub(:post, "https://slack.com/api/files.info").to_return do |request|
      form_body(request).should eq URI::Params.parse("file=F0AB1CD2EF3")
      HTTP::Client::Response.new(200, body: %({"ok":true,"file":{"id":"F0AB1CD2EF3","name":"notes.txt","mimetype":"text/plain"},"comments":[]}))
    end

    ApiSupport.client.call(Slack::Api::FilesInfo.new("F0AB1CD2EF3")).file.mimetype.should eq "text/plain"
  end
end

describe Slack::Api::FilesDelete do
  it "deletes one file" do
    WebMock.stub(:post, "https://slack.com/api/files.delete").to_return do |request|
      form_body(request).should eq URI::Params.parse("file=F0AB1CD2EF3")
      HTTP::Client::Response.new(200, body: %({"ok":true}))
    end

    ApiSupport.client.call(Slack::Api::FilesDelete.new("F0AB1CD2EF3")).ok?.should be_true
  end
end

describe "remote file requests" do
  it "adds, updates, shares, and removes a remote file by either identifier" do
    WebMock.stub(:post, "https://slack.com/api/files.remote.add").to_return do |request|
      form_body(request).should eq URI::Params.parse(
        "external_id=plan-2026-q4&external_url=https%3A%2F%2Fdocs.example.test%2Fplan&title=Q4+plan&filetype=gdoc")
      HTTP::Client::Response.new(200, body: %({"ok":true,"file":{"id":"F08EAQ813FW","title":"Q4 plan","external_id":"plan-2026-q4"}}))
    end
    WebMock.stub(:post, "https://slack.com/api/files.remote.update").to_return do |request|
      form_body(request).should eq URI::Params.parse("file=F08EAQ813FW&title=Q4+plan+v2")
      HTTP::Client::Response.new(200, body: %({"ok":true,"file":{"id":"F08EAQ813FW","title":"Q4 plan v2"}}))
    end
    WebMock.stub(:post, "https://slack.com/api/files.remote.share").to_return do |request|
      form_body(request).should eq URI::Params.parse("external_id=plan-2026-q4&channels=C1%2CC2")
      HTTP::Client::Response.new(200, body: %({"ok":true,"file":{"id":"F08EAQ813FW"}}))
    end
    WebMock.stub(:post, "https://slack.com/api/files.remote.remove").to_return do |request|
      form_body(request).should eq URI::Params.parse("external_id=plan-2026-q4")
      HTTP::Client::Response.new(200, body: %({"ok":true}))
    end

    client = ApiSupport.client
    added = client.call(Slack::Api::FilesRemoteAdd.new(external_id: "plan-2026-q4",
      external_url: "https://docs.example.test/plan", title: "Q4 plan", filetype: "gdoc")).file
    added.id.should eq "F08EAQ813FW"
    by_id = Slack::Api::RemoteFileTarget.file(added.id)
    by_external_id = Slack::Api::RemoteFileTarget.external_id("plan-2026-q4")
    client.call(Slack::Api::FilesRemoteUpdate.new(by_id, title: "Q4 plan v2")).file.title.should eq "Q4 plan v2"
    client.call(Slack::Api::FilesRemoteShare.new(by_external_id, channels: ["C1", "C2"])).file.id.should eq "F08EAQ813FW"
    client.call(Slack::Api::FilesRemoteRemove.new(by_external_id)).ok?.should be_true
  end

  it "rejects empty identifiers and share channels before dispatch" do
    request = Slack::Api::FilesRemoteShare.new(Slack::Api::RemoteFileTarget.file(""), channels: [] of String)
    request.validate.map(&.code).should eq %w[remote_file_target.id.empty files_remote_share.channels.empty]
  end
end

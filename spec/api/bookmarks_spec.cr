require "../spec_helper"
require "../support/api/webmock_client"

private def stub_form(method : String, form : String, response : String = %({"ok":true})) : Nil
  WebMock.stub(:post, "https://slack.com/api/#{method}")
    .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                    "Content-Type"  => "application/x-www-form-urlencoded"})
    .to_return do |request|
      URI::Params.parse(request.body.to_s).should eq URI::Params.parse(form)
      HTTP::Client::Response.new(200, body: response)
    end
end

private BOOKMARK_JSON = <<-JSON
  {"id":"Bk01","channel_id":"C1","title":"Runbook","link":"https://example.test/runbook",
   "emoji":":books:","icon_url":"https://example.test/favicon.ico","type":"link","entity_id":null,
   "date_created":1710000000,"date_updated":0,"rank":"g","last_updated_by_user_id":"U1",
   "last_updated_by_team_id":"T1","shortcut_id":null,"app_id":null}
  JSON

describe Slack::Api::BookmarksAdd do
  it "adds a link bookmark with an emoji and a parent folder" do
    stub_form("bookmarks.add",
      "channel_id=C1&title=Runbook&type=link&link=https%3A%2F%2Fexample.test%2Frunbook&emoji=%3Abooks%3A&parent_id=Bk00",
      %({"ok":true,"bookmark":#{BOOKMARK_JSON}}))

    request = Slack::Api::BookmarksAdd.new("C1", "Runbook", "https://example.test/runbook",
      emoji: ":books:", parent_id: "Bk00")
    bookmark = ApiSupport.client.call(request).bookmark

    bookmark.id.should eq "Bk01"
    bookmark.channel_id.should eq "C1"
    bookmark.title.should eq "Runbook"
    bookmark.link.should eq "https://example.test/runbook"
    bookmark.emoji.should eq ":books:"
    bookmark.type.should eq "link"
    bookmark.entity_id.should be_nil
    bookmark.date_created.should eq 1_710_000_000
    bookmark.last_updated_by_user_id.should eq "U1"
  end

  it "rejects an empty title or link before sending" do
    error = expect_raises(Slack::UI::ValidationError) do
      ApiSupport.client.call(Slack::Api::BookmarksAdd.new("C1", "", ""))
    end
    error.issues.map(&.code).should eq ["bookmarks.title.empty", "bookmarks_add.link.empty"]
  end

  it "raises the Slack error code for a rejected link" do
    stub_form("bookmarks.add", "channel_id=C1&title=Bad&type=link&link=ftp%3A%2F%2Fx",
      %({"ok":false,"error":"invalid_link"}))

    error = expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::BookmarksAdd.new("C1", "Bad", "ftp://x"))
    end
    error.code.should eq "invalid_link"
  end
end

describe Slack::Api::BookmarksEdit do
  it "sends only the changed fields" do
    stub_form("bookmarks.edit", "channel_id=C1&bookmark_id=Bk01&title=Runbook+v2",
      %({"ok":true,"bookmark":#{BOOKMARK_JSON}}))

    request = Slack::Api::BookmarksEdit.new("C1", "Bk01", title: "Runbook v2")
    ApiSupport.client.call(request).bookmark.id.should eq "Bk01"
  end

  it "rejects an edit without changes or with an empty title before sending" do
    error = expect_raises(Slack::UI::ValidationError) do
      ApiSupport.client.call(Slack::Api::BookmarksEdit.new("C1", "Bk01"))
    end
    error.issues.map(&.code).should eq ["bookmarks_edit.changes.empty"]

    error = expect_raises(Slack::UI::ValidationError) do
      ApiSupport.client.call(Slack::Api::BookmarksEdit.new("C1", "Bk01", title: ""))
    end
    error.issues.map(&.code).should eq ["bookmarks.title.empty"]
  end
end

describe Slack::Api::BookmarksList do
  it "reads the bookmarks of a channel" do
    stub_form("bookmarks.list", "channel_id=C1", %({"ok":true,"bookmarks":[#{BOOKMARK_JSON}]}))

    bookmarks = ApiSupport.client.call(Slack::Api::BookmarksList.new("C1")).bookmarks

    bookmarks.map(&.title).should eq ["Runbook"]
  end
end

describe Slack::Api::BookmarksRemove do
  it "removes a bookmark and raises not_found for an unknown one" do
    stub_form("bookmarks.remove", "channel_id=C1&bookmark_id=Bk01")
    ApiSupport.client.call(Slack::Api::BookmarksRemove.new("C1", "Bk01")).ok?.should be_true

    WebMock.reset
    stub_form("bookmarks.remove", "channel_id=C1&bookmark_id=Bk99", %({"ok":false,"error":"not_found"}))
    error = expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::BookmarksRemove.new("C1", "Bk99"))
    end
    error.code.should eq "not_found"
  end
end

require "../spec_helper"
require "../support/api/webmock_client"

private def stub_member_pages(requests : Array(URI::Params), pages : Array(String)) : Nil
  WebMock.stub(:post, "https://slack.com/api/conversations.members").to_return do |request|
    requests << URI::Params.parse(request.body.to_s)
    HTTP::Client::Response.new(200, body: pages[requests.size - 1])
  end
end

describe "Slack::Api::Client#each_page" do
  it "sends each next_cursor with the next request and stops on an empty cursor" do
    requests = [] of URI::Params
    stub_member_pages(requests, [
      %({"ok":true,"members":["U1","U2"],"response_metadata":{"next_cursor":"dXNlcjpVMw=="}}),
      %({"ok":true,"members":["U3"],"response_metadata":{"next_cursor":""}}),
    ])

    members = [] of String
    cursors = [] of String?
    ApiSupport.client.each_page(Slack::Api::ConversationsMembers.new("C1", limit: 2)) do |page|
      members.concat(page.model.members)
      cursors << page.next_cursor
    end

    members.should eq %w[U1 U2 U3]
    cursors.should eq ["dXNlcjpVMw==", nil]
    requests.should eq [
      URI::Params.parse("channel=C1&limit=2"),
      URI::Params.parse("channel=C1&cursor=dXNlcjpVMw%3D%3D&limit=2"),
    ]
  end

  it "stops when response_metadata or next_cursor is missing or null" do
    [%({"ok":true,"members":["U1"]}),
     %({"ok":true,"members":["U1"],"response_metadata":{}}),
     %({"ok":true,"members":["U1"],"response_metadata":{"next_cursor":null}})].each do |body|
      WebMock.reset
      requests = [] of URI::Params
      stub_member_pages(requests, [body])

      pages = 0
      ApiSupport.client.each_page(Slack::Api::ConversationsMembers.new("C1")) { pages += 1 }

      pages.should eq 1
      requests.size.should eq 1
    end
  end

  it "sends no further request after the block breaks" do
    requests = [] of URI::Params
    stub_member_pages(requests, [%({"ok":true,"members":["U1"],"response_metadata":{"next_cursor":"next"}})])

    first = ApiSupport.client.each_page(Slack::Api::ConversationsMembers.new("C1")) { |page| break page.next_cursor }

    first.should eq "next"
    requests.size.should eq 1
  end

  it "raises a Slack error from a later page after yielding the earlier pages" do
    requests = [] of URI::Params
    stub_member_pages(requests, [
      %({"ok":true,"members":["U1"],"response_metadata":{"next_cursor":"next"}}),
      %({"ok":false,"error":"invalid_cursor"}),
    ])

    pages = 0
    expect_raises(Slack::Api::Error, "invalid_cursor") do
      ApiSupport.client.each_page(Slack::Api::ConversationsMembers.new("C1")) { pages += 1 }
    end
    pages.should eq 1
  end

  it "rejects a limit outside 1 to 1000 before sending" do
    requests = [] of URI::Params
    stub_member_pages(requests, [%({"ok":true,"members":[]})])

    [0, 1001].each do |limit|
      error = expect_raises(Slack::UI::ValidationError) do
        ApiSupport.client.each_page(Slack::Api::ConversationsMembers.new("C1", limit: limit)) { }
      end
      error.issues.map(&.path).should eq ["limit"]
    end
    requests.should be_empty
  end
end

describe Slack::Api::Paginated do
  it "copies the request with a new cursor and keeps the original" do
    request = Slack::Api::ConversationsReplies.new("C1", "1710000000.000100", limit: 50)

    next_request = request.with_cursor("bmV4dA==")

    next_request.cursor.should eq "bmV4dA=="
    next_request.limit.should eq 50
    next_request.ts.should eq "1710000000.000100"
    request.cursor.should be_nil
  end
end

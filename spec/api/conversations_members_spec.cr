require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ConversationsMembers do
  it "sends the channel and page size and reads member IDs" do
    WebMock.stub(:post, "https://slack.com/api/conversations.members")
      .with(body: "channel=C123&cursor=e3VzZXJfaWQ6IFcxMjM0NTY3fQ%3D%3D&limit=100",
        headers: {"Content-Type" => "application/x-www-form-urlencoded"})
      .to_return(body: <<-JSON)
        {"ok":true,"members":["U023BECGF","U061F7AUR","W012A3CDE"],
        "response_metadata":{"next_cursor":""}}
        JSON

    request = Slack::Api::ConversationsMembers.new("C123", cursor: "e3VzZXJfaWQ6IFcxMjM0NTY3fQ==", limit: 100)

    ApiSupport.client.call(request).members.should eq %w[U023BECGF U061F7AUR W012A3CDE]
  end
end

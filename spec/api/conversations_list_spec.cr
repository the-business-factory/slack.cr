require "../spec_helper"
require "../support/api/webmock_client"

private LIST_RESPONSE = <<-JSON
  {
    "ok": true,
    "channels": [
      {"id": "C012AB3CD", "name": "general", "is_channel": true, "is_group": false, "is_im": false,
       "is_mpim": false, "is_private": false, "created": 1449252889, "is_archived": false, "is_general": true,
       "name_normalized": "general", "is_shared": false, "is_org_shared": false, "is_member": true,
       "creator": "U012A3CDE", "previous_names": [], "num_members": 4,
       "topic": {"value": "Company-wide", "creator": "", "last_set": 0},
       "purpose": {"value": "Announcements", "creator": "", "last_set": 0}},
      {"id": "C061EG9T2", "name": "design", "is_channel": true, "is_group": false, "is_im": false,
       "is_mpim": false, "is_private": true, "created": 1449252890, "is_archived": false, "is_member": true,
       "creator": "U061F7AUR"},
      {"id": "G0AKFJBEU", "name": "mpdm-mr.banks--slactions-jackson--beforebot-1", "is_channel": false,
       "is_group": true, "is_im": false, "is_mpim": true, "is_private": true, "created": 1493657761,
       "is_archived": false, "is_member": true, "creator": "U061F7AUR"},
      {"id": "D0C0F7S8Y", "created": 1498500348, "is_im": true, "is_org_shared": false, "user": "U0BS9U4SV",
       "is_user_deleted": false, "priority": 0}
    ],
    "response_metadata": {"next_cursor": "dGVhbTpDMDYxRkE1UEI="}
  }
  JSON

describe Slack::Api::ConversationsList do
  it "sends the filters as form fields and reads each conversation as its type" do
    WebMock.stub(:post, "https://slack.com/api/conversations.list")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                      "Content-Type"  => "application/x-www-form-urlencoded"})
      .to_return do |request|
        URI::Params.parse(request.body.to_s).should eq URI::Params.parse(
          "exclude_archived=true&limit=200&team_id=T123&types=public_channel%2Cprivate_channel%2Cmpim%2Cim")
        HTTP::Client::Response.new(200, body: LIST_RESPONSE)
      end

    request = Slack::Api::ConversationsList.new(
      types: [Slack::Api::ConversationType::PublicChannel, Slack::Api::ConversationType::PrivateChannel,
              Slack::Api::ConversationType::Mpim, Slack::Api::ConversationType::Im],
      exclude_archived: true, team_id: "T123", limit: 200)
    channels = ApiSupport.client.call(request).channels

    general = channels[0].should be_a(Slack::Models::PublicChannel)
    general.name.should eq "general"
    general.num_members.should eq 4
    design = channels[1].should be_a(Slack::Models::PrivateChannel)
    design.name.should eq "design"
    group = channels[2].should be_a(Slack::Models::PrivateChannel)
    group.is_mpim?.should be_true
    im = channels[3].should be_a(Slack::Models::IMChat)
    im.user.should eq "U0BS9U4SV"
    im.latest.should be_nil
  end

  it "omits unset filters so Slack applies its defaults" do
    WebMock.stub(:post, "https://slack.com/api/conversations.list")
      .with(body: "")
      .to_return(body: %({"ok":true,"channels":[]}))

    ApiSupport.client.call(Slack::Api::ConversationsList.new).channels.should be_empty
  end

  it "keeps its types after the caller changes the source or the returned array" do
    sent = [] of String
    WebMock.stub(:post, "https://slack.com/api/conversations.list").to_return do |http_request|
      sent << URI::Params.parse(http_request.body.to_s)["types"]
      HTTP::Client::Response.new(200, body: %({"ok":true,"channels":[]}))
    end
    types = [Slack::Api::ConversationType::PublicChannel]
    request = Slack::Api::ConversationsList.new(types: types)
    next_page = request.with_cursor("bmV4dA==")

    types << Slack::Api::ConversationType::PrivateChannel
    request.types.try &.clear
    client = ApiSupport.client
    client.call(request)
    client.call(next_page)

    sent.should eq ["public_channel", "public_channel"]
  end

  it "rejects an empty types list before sending" do
    error = expect_raises(Slack::UI::ValidationError) do
      ApiSupport.client.call(Slack::Api::ConversationsList.new(types: [] of Slack::Api::ConversationType))
    end
    error.issues.map(&.path).should eq ["types"]
  end

  it "reports a conversation without a known type flag as an invalid response" do
    WebMock.stub(:post, "https://slack.com/api/conversations.list")
      .to_return(body: %({"ok":true,"channels":[{"id":"X1","created":1}]}))

    expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ConversationsList.new)
    end.code.should eq "invalid_response"
  end
end

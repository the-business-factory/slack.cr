require "../spec_helper"

describe Slack::Helpers::Modal do
  it "opens a display modal without submit or close" do
    token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
    section = Slack::UI::Blocks::Section.new(
      text: Slack::UI::Blocks::Section::Text.new("Details")
    )
    blocks = [section] of Slack::TypeAliases::ModalBlock

    WebMock.stub(:post, "https://slack.com/api/views.open")
      .with(headers: {"Authorization" => "Bearer #{token}"})
      .to_return do |request|
        payload = JSON.parse(request.body || fail("Expected a JSON request body"))
        payload["trigger_id"].as_s.should eq "trigger"
        payload["view"].as_h.has_key?("submit").should be_false
        payload["view"].as_h.has_key?("close").should be_false
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{}}))
      end

    response = Slack::Helpers::Modal.open(
      access_token: token,
      blocks: blocks,
      trigger_id: "trigger",
      title: "Details"
    )

    response.ok?.should be_true
  end

  it "opens an input modal with submit and no close" do
    token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
    input = Slack::UI::Blocks::Input.new(
      label: Slack::UI::Blocks::Input::Label.new("Notes"),
      element: Slack::UI::BlockElements::PlainTextInput.new(action_id: "notes")
    )
    blocks = [input] of Slack::TypeAliases::ModalBlock

    WebMock.stub(:post, "https://slack.com/api/views.open")
      .with(headers: {"Authorization" => "Bearer #{token}"})
      .to_return do |request|
        view = JSON.parse(request.body || fail("Expected a JSON request body"))["view"]
        view["submit"]["text"].as_s.should eq "Save"
        view.as_h.has_key?("close").should be_false
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{}}))
      end

    response = Slack::Helpers::Modal.open(
      access_token: token,
      blocks: blocks,
      trigger_id: "trigger",
      title: "Notes",
      submit: "Save"
    )

    response.ok?.should be_true
  end

  it "keeps the existing six-argument call compatible" do
    token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
    section = Slack::UI::Blocks::Section.new(
      text: Slack::UI::Blocks::Section::Text.new("Details")
    )
    blocks = [section] of Slack::TypeAliases::ModalBlock

    WebMock.stub(:post, "https://slack.com/api/views.open")
      .to_return do |request|
        view = JSON.parse(request.body || fail("Expected a JSON request body"))["view"]
        view["submit"]["text"].as_s.should eq "Save"
        view["close"]["text"].as_s.should eq "Cancel"
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{}}))
      end

    Slack::Helpers::Modal.open(
      token,
      blocks,
      "Cancel",
      "Save",
      "trigger",
      "Details"
    ).ok?.should be_true
  end
end

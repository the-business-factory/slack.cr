require "../spec_helper"

describe Slack::Api::ViewsOpen do
  section = -> do
    Slack::UI::Blocks::Section.new(
      text: Slack::UI::Blocks::Section::Text.new("Details")
    )
  end
  input = -> do
    Slack::UI::Blocks::Input.new(
      label: Slack::UI::Blocks::Input::Label.new("Notes"),
      element: Slack::UI::BlockElements::PlainTextInput.new(action_id: "notes")
    )
  end

  it "rejects a retained blocks-array mutation through result before HTTP" do
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/views.open")
      .to_return do
        requests += 1
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{}}))
      end

    blocks = [section.call] of Slack::TypeAliases::ModalBlock
    modal = Slack::UI::Modal.new(
      title: Slack::UI::Modal::Title.new("Details"),
      blocks: blocks
    )
    request = Slack::Api::ViewsOpen.new(
      token: "synthetic-result-token",
      trigger_id: "trigger",
      view: modal
    )
    blocks << input.call

    expect_raises(
      Slack::Errors::InvalidUIBlock,
      "Modal submit is required when blocks include an input"
    ) do
      request.result
    end
    requests.should eq 0
  end

  it "rejects a submit-setter mutation through call before HTTP" do
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/views.open")
      .to_return do
        requests += 1
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{}}))
      end

    blocks = [input.call] of Slack::TypeAliases::ModalBlock
    modal = Slack::UI::Modal.new(
      title: Slack::UI::Modal::Title.new("Notes"),
      submit: Slack::UI::Modal::Submit.new("Save"),
      blocks: blocks
    )
    modal.submit = nil
    request = Slack::Api::ViewsOpen.new(
      token: "synthetic-call-token",
      trigger_id: "trigger",
      view: modal
    )

    expect_raises(
      Slack::Errors::InvalidUIBlock,
      "Modal submit is required when blocks include an input"
    ) do
      request.call
    end
    requests.should eq 0
  end

  it "sends a valid display modal through result" do
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/views.open")
      .to_return do |request|
        requests += 1
        view = JSON.parse(request.body || fail("Expected a JSON request body"))["view"]
        view.as_h.has_key?("submit").should be_false
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{}}))
      end

    blocks = [section.call] of Slack::TypeAliases::ModalBlock
    modal = Slack::UI::Modal.new(
      title: Slack::UI::Modal::Title.new("Details"),
      blocks: blocks
    )

    Slack::Api::ViewsOpen.new(
      token: "synthetic-valid-result-token",
      trigger_id: "trigger",
      view: modal
    ).result.status_code.should eq 200
    requests.should eq 1
  end

  it "sends a valid form modal through call" do
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/views.open")
      .to_return do |request|
        requests += 1
        view = JSON.parse(request.body || fail("Expected a JSON request body"))["view"]
        view["submit"]["text"].as_s.should eq "Save"
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{}}))
      end

    blocks = [input.call] of Slack::TypeAliases::ModalBlock
    modal = Slack::UI::Modal.new(
      title: Slack::UI::Modal::Title.new("Notes"),
      submit: Slack::UI::Modal::Submit.new("Save"),
      blocks: blocks
    )

    Slack::Api::ViewsOpen.new(
      token: "synthetic-valid-call-token",
      trigger_id: "trigger",
      view: modal
    ).call.ok?.should be_true
    requests.should eq 1
  end
end

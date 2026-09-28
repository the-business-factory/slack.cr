require "./spec_helper"
require "../examples/support/message_example"
require "../examples/support/modal_example"
require "../examples/support/home_example"
require "../examples/support/static_select_example"
require "../examples/support/overflow_example"
require "../examples/support/checkboxes_example"
require "../examples/support/radio_buttons_example"
require "../examples/support/message_update_example"

describe "documented Block Kit workflows" do
  around_each do |example|
    client_id = Slack.settings.client_id
    client_secret = Slack.settings.client_secret
    signing_secret = Slack.settings.signing_secret
    limiters = Slack::ApiClient.limiters.dup
    allow_net_connect = WebMock.allows_net_connect?
    begin
      Slack.configure do |settings|
        settings.client_id = nil
        settings.client_secret = nil
        settings.signing_secret = nil
      end
      Slack::ApiClient.limiters.clear
      example.run
    ensure
      Slack.configure do |settings|
        settings.client_id = client_id
        settings.client_secret = client_secret
        settings.signing_secret = signing_secret
      end
      Slack::ApiClient.limiters.clear
      Slack::ApiClient.limiters.merge!(limiters)
      WebMock.reset
      WebMock.allow_net_connect = allow_net_connect
    end
  end

  it "renders the message components" do
    output = IO::Memory.new
    OfflineMessageExample.run(output)
    message = JSON.parse(output.to_s)
    message["text"].should eq("Morgan's request 42 needs approval.")
    blocks = message["blocks"].as_a
    blocks.map(&.["type"].as_s).should eq(["section", "divider", "actions"])
    blocks[0]["text"]["text"].should eq("*Request 42* from Morgan")
    blocks[2]["elements"][0]["value"].should eq("42")
  end

  it "posts a button, opens a modal, and reads its signed submission" do
    output = IO::Memory.new
    OfflineModalExample.run(output)
    output.to_s.should eq("Saved request 42: Need a test environment. (acknowledged 200)\n")
  end

  it "publishes Home and reads the dispatched note" do
    output = IO::Memory.new
    OfflineHomeExample.run(output)
    output.to_s.should eq("Published Home V123 offline.\nReceived Home note: Ready to review\n")
  end

  it "posts a static select and reads the signed multi-select submission" do
    output = IO::Memory.new
    OfflineStaticSelectExample.run(output)
    output.to_s.should eq("Saved notification colors: red, blue (acknowledged 200)\n")
  end
  it "posts an overflow menu and acknowledges a signed URL selection" do
    output = IO::Memory.new
    OfflineOverflowExample.run(output)
    output.to_s.should eq "Selected request action: details (acknowledged 200)\n"
  end
  it "posts checkboxes and acknowledges checked and cleared signed selections" do
    output = IO::Memory.new
    OfflineCheckboxesExample.run(output)
    output.to_s.should eq "Selected notifications: digest (acknowledged 200)\nSaved notifications: none (acknowledged 200)\n"
  end
  it "posts radio buttons and reads signed selection and unselected submission state" do
    output = IO::Memory.new
    OfflineRadioButtonsExample.run(output)
    output.to_s.should eq "Selected delivery: digest (acknowledged 200)\nSaved delivery: none (acknowledged 200)\n"
  end

  it "replaces a posted approval prompt with its completed status" do
    output = IO::Memory.new
    OfflineMessageUpdateExample.run(output)
    output.to_s.should eq("Updated C123/1710000000.000001: Request 42 approved.\n")
  end
end

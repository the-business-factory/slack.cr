require "./spec_helper"
require "../examples/support/message_example"
require "../examples/support/modal_example"
require "../examples/support/home_example"
require "../examples/support/static_select_example"
require "../examples/support/overflow_example"
require "../examples/support/checkboxes_example"
require "../examples/support/radio_buttons_example"
require "../examples/support/message_update_example"
require "../examples/support/view_update_example"
require "../examples/support/users_select_example"
require "../examples/support/view_push_example"
require "../examples/support/modal_errors_example"
require "../examples/support/modal_clear_example"
require "../examples/support/channels_select_example"
require "../examples/support/modal_push_example"

require "../examples/support/modal_update_example"
require "../examples/support/conversations_select_example"

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
  it "updates an opened form using its returned ID and hash with stable input IDs" do
    output = IO::Memory.new
    OfflineViewUpdateExample.run(output)
    output.to_s.should eq("Updated modal V123 with stable reason/text input IDs (hash next-hash).\n")
  end
  it "assigns an owner and submits reviewers through signed user selections" do
    output = IO::Memory.new
    OfflineUsersSelectExample.run(output)
    output.to_s.should eq "Assigned owner: U-OWNER (acknowledged 200)\nSaved reviewers: U-ONE, W-TWO (acknowledged 200)\n"
  end
  it "pushes the next screen using a fresh interaction from an existing modal" do
    output = IO::Memory.new
    OfflineViewPushExample.run(output)
    output.to_s.should eq("Pushed details V2 onto modal V1 (acknowledged 200).\n")
  end
  it "returns field errors for a signed submission and accepts corrected input" do
    output = IO::Memory.new
    rejected, accepted = OfflineModalErrorsExample.run(output)
    rejected.status_code.should eq(200)
    rejected.headers["Content-Type"].should eq("application/json")
    rejected.body.should eq(%q({"response_action":"errors","errors":{"request.reason":"Explain why you need this request (at least 10 characters)."}}))
    accepted.status_code.should eq(200)
    accepted.body.should eq("")
    output.to_s.should eq("Rejected short reason; accepted corrected reason (HTTP 200).\n")
  end
  it "chooses a notification channel and submits destination channels" do
    output = IO::Memory.new
    OfflineChannelsSelectExample.run(output)
    output.to_s.should eq "Selected notification channel: C-NOTIFY (acknowledged 200)\nSaved destinations: C-ONE, C-TWO (acknowledged 200)\n"
  end
  it "prepares a clear acknowledgment for a signed successful submission" do
    output = IO::Memory.new
    response = OfflineModalClearExample.run(output)
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq("application/json")
    response.body.should eq(%q({"response_action":"clear"}))
    output.to_s.should eq("Accepted reason: Need a test environment. (prepared HTTP 200 clear)\n")
  end

  it "returns the next form in a signed submission acknowledgment" do
    output = IO::Memory.new
    response = OfflineModalPushExample.run(output)
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq("application/json")
    expected = JSON.parse(<<-JSON)
      {"response_action":"push","view":{"type":"modal","title":{"type":"plain_text","text":"Delivery details"},
        "submit":{"type":"plain_text","text":"Save"},"close":{"type":"plain_text","text":"Back"},
        "callback_id":"request.delivery","private_metadata":"42","blocks":[
          {"type":"section","text":{"type":"plain_text","text":"Reason: Need a test environment."}},
          {"type":"input","block_id":"delivery","label":{"type":"plain_text","text":"Delivery note"},
            "element":{"type":"plain_text_input","action_id":"note","multiline":true}}]}}
      JSON
    JSON.parse(response.body).should eq(expected)
    output.to_s.should eq("Prepared delivery form from signed submission (HTTP 200).\n")
  end

  it "acknowledges a signed submission with an updated form and retained input IDs" do
    output = IO::Memory.new
    response = OfflineModalUpdateExample.run(output)
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq("application/json")
    # Complete acknowledgment expected independently of the example's builder.
    JSON.parse(response.body).should eq(JSON.parse(<<-JSON))
      {"response_action":"update","view":{"type":"modal",
        "title":{"type":"plain_text","text":"Review request"},"submit":{"type":"plain_text","text":"Save"},
        "callback_id":"request.review","private_metadata":"42","blocks":[
          {"type":"section","text":{"type":"plain_text","text":"Choose an owner for: Need a test environment."}},
          {"type":"input","block_id":"request.reason","label":{"type":"plain_text","text":"Reason"},
            "element":{"type":"plain_text_input","action_id":"reason","multiline":true}},
          {"type":"input","block_id":"request.owner","label":{"type":"plain_text","text":"Owner"},
            "element":{"type":"users_select","action_id":"owner"}}]}}
      JSON
    output.to_s.should eq("Prepared updated form with retained request.reason/reason IDs (HTTP 200).\n")
  end
  it "acknowledges a long submitted reason with a bounded display preview" do
    Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
    payload = %({"type":"view_submission","view":{"type":"modal","callback_id":"request.reason","private_metadata":"42","state":{"values":{"request.reason":{"reason":{"type":"plain_text_input","value":"#{"界" * 3000}"}}}}}})
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "Content-Type"              => "application/x-www-form-urlencoded",
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }
    response = OfflineModalUpdateExample.handle(HTTP::Request.new("POST", "/interactions", headers, body))
    response.status_code.should eq(200)
    wire = JSON.parse(response.body)
    wire["response_action"].as_s.should eq("update")
    wire["view"]["blocks"][0]["text"]["text"].as_s.should eq("Choose an owner for: #{"界" * 200}…")
  end

  it "chooses a filtered conversation and submits conversation destinations" do
    output = IO::Memory.new
    OfflineConversationsSelectExample.run(output)
    output.to_s.should eq "Selected notification conversation: D-NOTIFY (acknowledged 200)\nSaved destinations: C-ONE, G-TWO (acknowledged 200)\n"
  end
end

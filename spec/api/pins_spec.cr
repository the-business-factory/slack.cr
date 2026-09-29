require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::PinsAdd do
  it "pins a message to its channel" do
    ApiSupport.stub_form("pins.add", "channel=C1&timestamp=1710000000.000100")

    ApiSupport.client.call(Slack::Api::PinsAdd.new("C1", "1710000000.000100")).ok?.should be_true
  end

  it "raises already_pinned when the message is already pinned" do
    ApiSupport.stub_form("pins.add", "channel=C1&timestamp=1710000000.000100", %({"ok":false,"error":"already_pinned"}))

    error = expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::PinsAdd.new("C1", "1710000000.000100"))
    end
    error.code.should eq "already_pinned"
  end
end

describe Slack::Api::PinsRemove do
  it "unpins a message" do
    ApiSupport.stub_form("pins.remove", "channel=C1&timestamp=1710000000.000100")

    ApiSupport.client.call(Slack::Api::PinsRemove.new("C1", "1710000000.000100")).ok?.should be_true
  end
end

describe Slack::Api::PinsList do
  it "reads the pinned messages of a channel with who pinned them and when" do
    ApiSupport.stub_form("pins.list", "channel=C1", <<-JSON)
      {"ok":true,"items":[
        {"type":"message","channel":"C1","created":1710000500,"created_by":"U2",
         "message":{"type":"message","text":"Runbook: restart the queue","user":"U1","ts":"1710000000.000100",
          "permalink":"https://example.slack.com/archives/C1/p1710000000000100","pinned_to":["C1"]}}]}
      JSON

    items = ApiSupport.client.call(Slack::Api::PinsList.new("C1")).items

    items.size.should eq 1
    pin = items.first
    pin.type.should eq "message"
    pin.channel.should eq "C1"
    pin.created_by.should eq "U2"
    pin.created.should eq 1_710_000_500
    pin.message.try(&.text).should eq "Runbook: restart the queue"
    pin.file.should be_nil
  end
end

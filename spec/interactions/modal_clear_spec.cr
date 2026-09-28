require "../spec_helper"

describe Slack::Interactions::ModalClear do
  it "serializes the complete acknowledgment for closing all modal views" do
    Slack::Interactions::ModalClear.new.to_json.should eq(%q({"response_action":"clear"}))
  end
end

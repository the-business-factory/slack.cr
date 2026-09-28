require "../spec_helper"

describe Slack::Interactions::ModalClear do
  it "serializes the complete acknowledgment for closing all modal views" do
    Slack::Interactions::ModalClear.new.to_json.should eq(%q({"response_action":"clear"}))
  end

  it "preserves the legacy CLOSE named tuple and its wire body" do
    response : NamedTuple(response_action: String) = Slack::Helpers::Modal::CLOSE
    response.to_json.should eq(%q({"response_action":"clear"}))
  end
end

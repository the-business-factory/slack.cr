require "../spec_helper"

describe Slack::Interactions::ModalErrors do
  it "serializes complete block-ID errors with plain text and JSON escaping" do
    response = Slack::Interactions::ModalErrors.new({
      "request.reason" => "Explain \"why\".\nUse a concrete example.",
      "request.date"   => "Choose a future date & retry.",
    })
    response.to_json.should eq(%q({"response_action":"errors","errors":{"request.reason":"Explain \"why\".\nUse a concrete example.","request.date":"Choose a future date & retry."}}))
  end

  it "owns its errors independently of caller and getter mutations" do
    errors = {"reason" => "Give a reason."}
    response = Slack::Interactions::ModalErrors.new(errors)
    errors["reason"] = "Changed"
    copy = response
    copy.errors.clear
    response.errors["other"] = "Injected"
    expected = %q({"response_action":"errors","errors":{"reason":"Give a reason."}})
    response.to_json.should eq(expected)
    copy.to_json.should eq(expected)
  end

  it "rejects an empty error map and blank messages as library policy" do
    expect_raises(Slack::UI::ValidationError, "Supply at least one") do
      Slack::Interactions::ModalErrors.new({} of String => String)
    end
    expect_raises(Slack::UI::ValidationError, "must not be blank") do
      Slack::Interactions::ModalErrors.new({"reason" => " \n"})
    end
  end
end

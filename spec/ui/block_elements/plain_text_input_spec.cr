require "../../spec_helper"

describe Slack::UI::BlockElements::PlainTextInput do
  input = ->(min_length : Int32?, max_length : Int32?) do
    Slack::UI::BlockElements::PlainTextInput.new(
      action_id: "notes",
      min_length: min_length,
      max_length: max_length
    )
  end

  it "accepts the minimum-length bounds and adjacent valid values" do
    input.call(0, nil)
    input.call(1, nil)
    input.call(2999, nil)
    input.call(3000, nil)
  end

  it "rejects minimum lengths below zero and above 3000" do
    expect_raises(Slack::Errors::InvalidUIBlock, "min_length must be between 0 and 3000") do
      input.call(-1, nil)
    end
    expect_raises(Slack::Errors::InvalidUIBlock, "min_length must be between 0 and 3000") do
      input.call(3001, nil)
    end
  end

  it "accepts the maximum-length bounds and adjacent valid values" do
    input.call(nil, 1)
    input.call(nil, 2)
    input.call(nil, 2999)
    input.call(nil, 3000)
  end

  it "rejects maximum lengths below one and above 3000" do
    expect_raises(Slack::Errors::InvalidUIBlock, "max_length must be between 1 and 3000") do
      input.call(nil, 0)
    end
    expect_raises(Slack::Errors::InvalidUIBlock, "max_length must be between 1 and 3000") do
      input.call(nil, 3001)
    end
  end

  it "accepts equal bounds and rejects a minimum above the maximum" do
    input.call(1, 1)

    expect_raises(Slack::Errors::InvalidUIBlock, "min_length cannot be greater than max_length") do
      input.call(2, 1)
    end
  end

  it "preserves zero and false while omitting absent optional values" do
    payload = JSON.parse(input.call(0, nil).to_json)

    payload["min_length"].as_i.should eq 0
    payload["multiline"].as_bool.should be_false
    payload["focus_on_load"].as_bool.should be_false
    payload.as_h.has_key?("max_length").should be_false
    payload.as_h.has_key?("initial_value").should be_false
    payload.as_h.has_key?("dispatch_action_config").should be_false
  end
end

require "./spec_helper"

describe "Offline HTTP fixtures" do
  it "rejects unstubbed ordinary and streaming requests" do
    expect_raises(WebMock::NetConnectNotAllowedError) do
      HTTP::Client.get("https://offline.invalid/unrecorded")
    end
    expect_raises(WebMock::NetConnectNotAllowedError) do
      HTTP::Client.get("https://offline.invalid/unrecorded") { |_| }
    end
  end
end

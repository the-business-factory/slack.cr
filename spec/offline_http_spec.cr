require "./spec_helper"

describe "Offline HTTP fixtures" do
  it "rejects requests without a cassette" do
    expect_raises(Exception, "Missing VCR recording for GET /unrecorded in nil") do
      HTTP::Client.get("https://slack.com/unrecorded")
    end
  end

  it "rejects requests that do not match a recording" do
    load_cassette("team-info-success") do
      expect_raises(Exception, "Missing VCR recording for GET /unrecorded") do
        HTTP::Client.get("https://slack.com/unrecorded")
      end
    end
  end
end

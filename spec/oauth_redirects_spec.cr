require "./spec_helper"

describe "OAuth redirect validation" do
  it "rejects missing and blank login redirects before authorization or exchange" do
    original = Slack::SignInWithSlack.settings.sign_in_redirect_url
    handler = Slack::SignInWithSlack.new
    [nil, "", " \t\n"].each do |value|
      Slack::SignInWithSlack.configure(&.sign_in_redirect_url=(value))
      expected = "Slack::SignInWithSlack.sign_in_redirect_url is required and must not be blank"
      expect_raises(Habitat::InvalidSettingFormatError) { handler.redirect_url }.message.should eq(expected)
      error = expect_raises(Habitat::InvalidSettingFormatError) do
        handler.authenticate_user(HTTP::Request.new("GET", "/callback?code=secret-code"))
      end
      error.message.should eq(expected)
    end
  ensure
    Slack::SignInWithSlack.configure(&.sign_in_redirect_url=(original))
  end
end

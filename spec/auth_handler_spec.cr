require "./spec_helper"
require "../src/slack/oauth/**"

# Because this is a 2-step process, we need to stub the HTTP client, as the
# auth flow is: user clicks link, Slack redirects to our app, then the app uses
# that request to send *another* request to slack, which finally responds with
# the authentication tokens.
class StubClient < HTTP::Client
  def post(_url, **_args)
    HTTP::Client::Response.new(
      status: HTTP::Status::OK,
      body: File.read("spec/fixtures/auth_success.json")
    )
  end
end

describe Slack::AuthHandler do
  describe "#redirect_url" do
    it "should combine the proper URL to install the app" do
      base_url = "https://slack.com/oauth/v2/authorize?"
      expected = [
        base_url,
        "client_id=#{Slack.settings.client_id}&",
        "scope=#{Slack.settings.bot_scopes.join(",")}&",
        "redirect_uri=#{Slack::AuthHandler.settings.oauth_redirect_url}&",
        "user_scope=#{Slack.settings.user_scopes.join(", ")}",
      ].join
      Slack::AuthHandler.new.redirect_url.should eq expected
    end
  end

  describe ".run" do
    context "without forgery protection via state param" do
      it "should take an oauth2 request from slack and return the auth info" do
        request = HTTP::Request.new(
          "GET",
          "/auth/slack?code=123455",
          headers: HTTP::Headers.new
        )

        result = Slack::AuthHandler.run(request, StubClient.new("example.com"))
        result.team.name.should eq "Slack Softball Team"
      end
    end
  end
end

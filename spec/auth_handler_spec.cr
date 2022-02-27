require "./spec_helper"
require "../src/slack/oauth/**"

# Because this is a 2-step process, we need to stub the HTTP client, as the
# auth flow is: user clicks link, Slack redirects to our app, then the app uses
# that request to send *another* request to slack, which finally responds with
# the authentication tokens.
class StubClient < HTTP::Client
  struct StubResponse
    property body : String

    def initialize(@body)
    end
  end

  def self.post(**kwargs)
    StubResponse.new File.read("spec/fixtures/auth_success.json")
  end
end

describe Slack::AuthHandler do
  describe ".run" do
    context "without forgery protection via state param" do
      it "should take an oauth2 request from slack and return the auth info" do
        request = HTTP::Request.new(
          "GET",
          "/auth/slack?code=123455",
          headers: HTTP::Headers.new
        )

        result = Slack::AuthHandler.run(request, StubClient)
        result.team.name.should eq "Slack Softball Team"
      end
    end
  end
end

require "./spec_helper"
require "../src/slack/oauth/**"

describe Slack::AuthHandler do
  describe ".run" do
    context "without forgery protection via state param" do
      it "should take an oauth2 request from slack and return the auth info" do
        request = HTTP::Request.new(
          "GET",
          "/auth/slack?code=123455",
          headers: HTTP::Headers.new
        )

        result = Slack::AuthHandler.run(request)
      end
    end
  end
end

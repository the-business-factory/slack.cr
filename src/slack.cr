require "habitat"
require "http"
require "json"
require "./slack/mixins/**"
require "./slack/events/**"

module Slack
  Habitat.create do
    setting app_scopes : Array(String) = ["incoming-webhook"]
    setting client_id : String = ENV["SLACK_CLIENT_ID"]
    setting client_secret : String = ENV["SLACK_CLIENT_SECRET"]
    setting signing_secret : String = ENV["SLACK_SIGNING_SECRET"]
    setting signing_secret_version : String = "v0"
    setting webhook_delivery_time_limit : Time::Span = 5.minutes
  end

  def self.process_request(request : HTTP::Request)
    from_json Webhooks::VerifiedRequest.new(request: request).verify!.body
  end

  def self.from_json(json : String | IO)
    pull = JSON::PullParser.new(json)
    original = JSON::PullParser.new(json)
    default = nil

    pull.read_object do |key|
      case key
      when "challenge"
        pull.read_string
        default = Slack::UrlVerification.from_json(json)
      else
        pull.skip
      end
    end

    default || Slack::VerifiedEvent.new(original)
  end
end

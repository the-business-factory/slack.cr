require "habitat"
require "http"
require "json"
require "openssl/hmac"
require "./slack/mixins/**"
require "./slack/types/**"
require "./slack/errors/**"
require "./slack/api/endpoints/base"
require "./slack/api/**"
require "./slack/commands/**"
require "./slack/event"
require "./slack/events/**"
require "./slack/interaction"
require "./slack/interactions/**"
require "./slack/model"
require "./slack/models/**"
require "./slack/webhooks/**"
require "./slack/ui/dynamic_text_composition"
require "./slack/ui/composition_objects/**"
require "./slack/ui/**"

module Slack
  Habitat.create do
    setting bot_scopes : Array(String) = [] of String
    setting client_id : String = ENV["SLACK_CLIENT_ID"]
    setting client_secret : String = ENV["SLACK_CLIENT_SECRET"]
    setting user_scopes : Array(String) = [] of String
    setting signing_secret : String = ENV["SLACK_SIGNING_SECRET"]
    setting signing_secret_version : String = "v0"
    setting webhook_delivery_time_limit : Time::Span = 5.minutes
  end

  def self.process_webhook(request : HTTP::Request)
    from_json Webhooks::VerifiedRequest.new(request: request).verify!.body
  end

  def self.process_command(request : HTTP::Request) : Slack::Command
    verified_body = Webhooks::VerifiedRequest.new(request: request).verify!.body
    Command.from_json URI::Params.parse(verified_body).to_h.to_json
  end

  def self.process_interaction(request : HTTP::Request)
    verified_body = Webhooks::VerifiedRequest.new(request: request).verify!.body
    Interaction.from_json URI::Params.parse(verified_body).to_h["payload"]
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

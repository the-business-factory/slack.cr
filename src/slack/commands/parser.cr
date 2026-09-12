require "json"
require "uri"
require "../auth/request_authorization_error"
require "./command"

module Slack::Commands::Parser
  ROUTING_KEYS = %w[api_app_id enterprise_id is_enterprise_install team_id user_id]

  def self.parse(body : String) : Slack::Command
    values = Hash(String, Array(String)).new { |hash, key| hash[key] = [] of String }
    URI::Params.parse(body).each { |key, value| values[key] << value }
    ROUTING_KEYS.each do |key|
      if entries = values[key]?
        raise Slack::Auth::RequestAuthorizationError.new(:duplicate_routing_field) if entries.size > 1
      end
    end

    object = {} of String => JSON::Any
    values.each do |key, entries|
      value = entries.last
      object[key] = key == "is_enterprise_install" ? JSON::Any.new(parse_boolean(value)) : JSON::Any.new(value)
    end
    Slack::Command.from_json(object.to_json)
  end

  private def self.parse_boolean(value : String) : Bool
    case value.strip
    when "true"  then true
    when "false" then false
    else
      raise Slack::Auth::RequestAuthorizationError.new(:invalid_install_kind)
    end
  end
end

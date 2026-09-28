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

  # Parses a slash command that arrives as a JSON object, as in a Socket Mode
  # envelope. It applies the rules of `.parse`: a repeated routing field is
  # rejected, another repeated field keeps its last value, and
  # `is_enterprise_install` must be `"true"` or `"false"` (a JSON boolean is
  # also accepted).
  def self.from_json_object(json : String) : Slack::Command
    object = {} of String => JSON::Any
    pull = JSON::PullParser.new(json)
    pull.read_object do |key|
      if object.has_key?(key) && ROUTING_KEYS.includes?(key)
        raise Slack::Auth::RequestAuthorizationError.new(:duplicate_routing_field)
      end
      value = JSON::Any.new(pull)
      object[key] = key == "is_enterprise_install" ? JSON::Any.new(json_boolean(value)) : value
    end
    Slack::Command.from_json(object.to_json)
  end

  private def self.json_boolean(value : JSON::Any) : Bool
    raw = value.raw
    case raw
    when Bool   then raw
    when String then parse_boolean(raw)
    else
      raise Slack::Auth::RequestAuthorizationError.new(:invalid_install_kind)
    end
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

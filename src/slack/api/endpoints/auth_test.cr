require "json"
require "../../auth/transport"
require "../../models/auth/test"
require "../auth_test_error"

class Slack::Api::AuthTest
  # The injected transport supplies authorization. RequestContext uses ScopedTransport.
  def initialize(@transport : Slack::Auth::Transport, @configuration : Slack::Auth::APIConfiguration)
  end

  def call : Slack::Models::Auth::Test
    uri = @configuration.base_uri.resolve("auth.test")
    request = Slack::Auth::TransportRequest.new("POST", uri,
      HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"})
    response = @transport.execute(request)
    self.class.parse(response.body, response.status, response.headers)
  end

  def self.parse(source : String | IO, status : Int32 = 200,
                 headers : HTTP::Headers = HTTP::Headers.new) : Slack::Models::Auth::Test
    fail_for_status(status, headers) unless 200 <= status < 300
    body = source.is_a?(String) ? source : source.gets_to_end
    object = JSON.parse(body).as_h
    ok = object["ok"]?.try(&.as_bool?)
    failure(:invalid_response, http_status: status) if ok.nil?
    api_failure(object["error"]?.try(&.as_s?), status) unless ok

    Slack::Models::Auth::Test.new(
      user_id: required_string(object, "user_id", status),
      bot_id: optional_string(object, "bot_id", status),
      team_id: optional_string(object, "team_id", status),
      enterprise_id: optional_string(object, "enterprise_id", status),
      url: optional_string(object, "url", status),
      team: optional_string(object, "team", status),
      user: optional_string(object, "user", status),
      is_enterprise_install: optional_bool(object, "is_enterprise_install", status),
    )
  rescue JSON::ParseException | TypeCastError | IO::Error
    failure(:invalid_response, http_status: status)
  end

  private def self.fail_for_status(status : Int32, headers : HTTP::Headers) : NoReturn
    if status == 429
      seconds = headers["Retry-After"]?.try(&.to_i64?)
      retry_after = seconds.try { |value| value >= 0 ? value.seconds : nil }
      failure(:rate_limited, http_status: status, retry_after: retry_after)
    elsif status >= 500
      failure(:server_error, http_status: status)
    else
      failure(:http_error, http_status: status)
    end
  end

  private def self.api_failure(code : String?, status : Int32) : NoReturn
    case code
    when "invalid_auth", "token_revoked", "account_inactive"
      failure(:reauthorization_required, Slack::Auth::ErrorCode::ReauthorizationRequired, status)
    when "missing_scope"
      failure(:missing_scope, http_status: status)
    else
      failure(:api_error, http_status: status)
    end
  end

  private def self.required_string(object : Hash(String, JSON::Any), key : String, status : Int32) : String
    value = optional_string(object, key, status)
    failure(:invalid_response, http_status: status) unless value
    value
  end

  private def self.optional_string(object : Hash(String, JSON::Any), key : String, status : Int32) : String?
    value = object[key]?
    return unless value
    return if value.raw.nil?
    string = value.as_s?
    failure(:invalid_response, http_status: status) if string.nil? || string.empty?
    string
  end

  private def self.optional_bool(object : Hash(String, JSON::Any), key : String, status : Int32) : Bool?
    value = object[key]?
    return unless value
    return if value.raw.nil?
    boolean = value.as_bool?
    failure(:invalid_response, http_status: status) if boolean.nil?
    boolean
  end

  private def self.failure(reason : Symbol, code : Slack::Auth::ErrorCode = Slack::Auth::ErrorCode::InvalidResponse,
                           http_status : Int32? = nil, retry_after : Time::Span? = nil) : NoReturn
    raise Slack::Api::AuthTestError.new(reason, code, http_status, retry_after)
  end
end

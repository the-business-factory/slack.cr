require "json"
require "http"
require "../auth/contracts"
require "./response_error"

# Internal, single-pass wire validation shared by both OAuth grant types.
struct Slack::Auth::ResponseParser
  @data : Hash(String, JSON::Any)
  @retry_after : Time::Span?

  def initialize(body : String | IO, @status : Int32, headers : HTTP::Headers)
    retry_seconds = headers["Retry-After"]?.try(&.to_i32?)
    @retry_after = retry_seconds.try { |seconds| seconds >= 0 ? seconds.seconds : nil }
    @data = read_body(body)
    unless (200..299).includes?(@status) && @data["ok"]?.try(&.as_bool?) == true
      remote = @data["ok"]?.try(&.as_bool?) == false ? @data["error"]?.try(&.as_s?) : nil
      allowed = {"invalid_code", "code_already_used", "invalid_refresh_token", "token_revoked", "invalid_grant", "invalid_client_id", "bad_client_secret", "invalid_client_secret", "ratelimited"}
      safe_error = remote && allowed.includes?(remote) ? remote : nil
      rejected = {"invalid_code", "code_already_used", "invalid_refresh_token", "token_revoked", "invalid_grant"}.includes?(safe_error)
      code = rejected ? ErrorCode::ReauthorizationRequired : ErrorCode::InvalidResponse
      raise ResponseError.new(code, @status, @retry_after, safe_error)
    end
  end

  private def read_body(body : String | IO) : Hash(String, JSON::Any)
    # Use the UTF-8-validating IO lexer for both input forms without rereading streams.
    input = body.is_a?(String) ? IO::Memory.new(body) : body
    JSON.parse(input).as_h? || invalid!
  rescue JSON::ParseException | IO::Error | InvalidByteSequenceError
    invalid!
  end

  def invalid! : NoReturn
    raise ResponseError.new(ErrorCode::InvalidResponse, @status, @retry_after)
  end

  def string(key : String, object : Hash(String, JSON::Any) = @data) : String?
    value = object[key]?
    return if value.nil? || value.raw.nil?
    result = value.as_s? || invalid!
    invalid! if result.empty?
    result
  end

  def required_string(key : String, object : Hash(String, JSON::Any) = @data) : String
    string(key, object) || invalid!
  end

  def object(key : String) : Hash(String, JSON::Any)?
    value = @data[key]?
    return if value.nil? || value.raw.nil?
    value.as_h? || invalid!
  end

  def boolean(key : String, default : Bool = false) : Bool
    value = @data[key]?
    return default if value.nil?
    result = value.as_bool?
    result.nil? ? invalid! : result
  end

  def expiry(object : Hash(String, JSON::Any) = @data) : Int32?
    value = object["expires_in"]?
    return if value.nil? || value.raw.nil?
    seconds = value.as_i64? || invalid!
    invalid! unless 0 < seconds <= Int32::MAX
    seconds.to_i32
  end

  def validate_grant(access : String?, scope : String?, token_type : String?,
                     refresh : String?, seconds : Int32?, kind : String) : Nil
    if access
      invalid! unless scope && token_type == kind
      invalid! if refresh.nil? != seconds.nil?
    elsif scope || token_type || refresh || seconds
      invalid!
    end
  end

  def self.scopes(scope : String) : Array(String)
    scope.split(',').map(&.strip).reject(&.empty?).uniq!
  end
end

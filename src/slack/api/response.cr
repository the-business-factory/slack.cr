require "json"
require "../auth/transport"
require "./error"
require "./rate_limited"
require "./envelope"
require "./decoded_response"

module Slack::Api
  # The parsed Web API envelope and the response model `M`. `parse` reads a
  # success body once. A body that does not decode as the model, such as an
  # error body, is parsed a second time for the envelope fields alone.
  #
  # See https://docs.slack.dev/apis/web-api/ for `ok`, `error`, and `warning`,
  # and https://docs.slack.dev/apis/web-api/pagination for `response_metadata`.
  struct Response(M)
    getter model : M
    getter warnings : Array(String)
    getter next_cursor : String?

    def initialize(@model : M, @warnings : Array(String), @next_cursor : String?)
    end

    # Raises `RateLimited` for HTTP 429 and `Error` for any other failure.
    def self.parse(response : Auth::TransportResponse) : self
      status = response.status
      # Do not parse a 429 body: the status and header carry the contract.
      raise RateLimited.new(retry_after(response.headers)) if status == 429

      decoded = decode(response.body)
      # Every Web API response has `ok`. A body without it is not one.
      raise Error.new(success?(status) ? "invalid_response" : "http_error", status) if decoded.ok.nil?
      metadata = decoded.response_metadata
      unless decoded.ok || flagged_outcome?(decoded)
        raise Error.new(decoded.error || "unknown_error", status, metadata.try(&.messages) || [] of String,
          details: details(decoded))
      end
      raise Error.new("http_error", status) unless success?(status)
      model = decoded.model
      raise Error.new("invalid_response", status) if model.nil?

      new(model, warnings(decoded), metadata.try(&.next_cursor).presence)
    end

    private def self.decode(body : String) : DecodedResponse(M)
      decode(body, M)
    end

    private def self.decode(body : String, type : JSON::Any.class) : DecodedResponse(JSON::Any)
      DecodedResponse(JSON::Any).new(JSON.parse(body))
    rescue JSON::ParseException
      DecodedResponse(JSON::Any).unreadable
    end

    private def self.decode(body : String, type : T.class) : DecodedResponse(T) forall T
      type.from_api_response(body)
    end

    # True when Slack answers `ok: false` with no `error` and the model's
    # outcome flag set, such as `{"ok": false, "not_in_channel": true}`.
    private def self.flagged_outcome?(decoded : DecodedResponse(M)) : Bool
      decoded.error.nil? && decoded.flagged_outcome?
    end

    private def self.details(decoded : DecodedResponse(M)) : Array(ErrorDetail)
      entries = decoded.errors.try(&.as_a?) || [] of JSON::Any
      entries.compact_map do |entry|
        next unless fields = entry.as_h?
        next unless message = fields["message"]?.try(&.as_s?)
        ErrorDetail.new(message, fields["pointer"]?.try(&.as_s?))
      end
    end

    private def self.warnings(decoded : DecodedResponse(M)) : Array(String)
      codes = decoded.warning.try(&.split(',').map(&.strip)) || [] of String
      codes.concat(decoded.response_metadata.try(&.warnings) || [] of String)
      codes.reject(&.empty?).uniq!
    end

    private def self.retry_after(headers : HTTP::Headers) : Time::Span?
      seconds = headers["Retry-After"]?.try(&.to_i64?)
      seconds.seconds if seconds && seconds >= 0
    end

    private def self.success?(status : Int32) : Bool
      200 <= status < 300
    end
  end
end

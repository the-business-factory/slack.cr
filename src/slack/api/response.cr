require "json"
require "../auth/transport"
require "./error"
require "./rate_limited"
require "./envelope"

module Slack::Api
  # The parsed Web API envelope and the response model `M`.
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
    # *outcome_flags* are the request's `Request#outcome_flags`.
    def self.parse(response : Auth::TransportResponse, outcome_flags : Array(String) = [] of String) : self
      status = response.status
      # Do not parse a 429 body: the status and header carry the contract.
      raise RateLimited.new(retry_after(response.headers)) if status == 429

      envelope = parse_envelope(response.body, status)
      metadata = envelope.response_metadata
      unless envelope.ok? || flagged_outcome?(envelope, response.body, outcome_flags)
        raise Error.new(envelope.error || "unknown_error", status, metadata.try(&.messages) || [] of String,
          details: details(envelope))
      end
      raise Error.new("http_error", status) unless success?(status)

      new(parse_model(response.body, status), warnings(envelope), metadata.try(&.next_cursor).presence)
    end

    private def self.parse_envelope(body : String, status : Int32) : Envelope
      Envelope.from_json(body)
    rescue JSON::ParseException
      raise Error.new(success?(status) ? "invalid_response" : "http_error", status)
    end

    # True when Slack answers `ok: false` with no `error` and one of the request's
    # flag fields set, such as `{"ok": false, "not_in_channel": true}`.
    private def self.flagged_outcome?(envelope : Envelope, body : String, outcome_flags : Array(String)) : Bool
      return false if envelope.error || outcome_flags.empty?

      # The envelope parsed, so the body is a JSON object.
      fields = JSON.parse(body)
      outcome_flags.any? { |flag| fields[flag]?.try(&.as_bool?) == true }
    end

    private def self.parse_model(body : String, status : Int32) : M
      M.from_json(body)
    rescue JSON::ParseException | TypeCastError | ArgumentError
      # Converters such as String#to_f raise ArgumentError with the remote value in
      # the message. Replace it without a cause so no response text escapes.
      raise Error.new("invalid_response", status)
    end

    private def self.details(envelope : Envelope) : Array(ErrorDetail)
      entries = envelope.errors.try(&.as_a?) || [] of JSON::Any
      entries.compact_map do |entry|
        next unless fields = entry.as_h?
        next unless message = fields["message"]?.try(&.as_s?)
        ErrorDetail.new(message, fields["pointer"]?.try(&.as_s?))
      end
    end

    private def self.warnings(envelope : Envelope) : Array(String)
      codes = envelope.warning.try(&.split(',').map(&.strip)) || [] of String
      codes.concat(envelope.response_metadata.try(&.warnings) || [] of String)
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

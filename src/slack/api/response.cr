require "json"
require "../auth/transport"
require "./error"
require "./rate_limited"
require "./envelope"
require "./envelope_body"

module Slack::Api
  # The parsed Web API envelope and the response model `M`. `parse` reads
  # both from one parse of the body.
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

      body = response.body
      decoded = decode(body)
      envelope = decoded ? decoded[1] : parse_envelope(body, status)
      # Every Web API response has `ok`. A body without it is not one.
      raise Error.new(success?(status) ? "invalid_response" : "http_error", status) unless envelope.ok_present?
      metadata = envelope.response_metadata
      unless envelope.ok? || flagged_outcome?(envelope)
        raise Error.new(envelope.error || "unknown_error", status, metadata.try(&.messages) || [] of String,
          details: details(envelope))
      end
      raise Error.new("http_error", status) unless success?(status)
      # Converters such as String#to_f raise with the remote value in the
      # message, so no decode error becomes the cause.
      raise Error.new("invalid_response", status) unless decoded

      new(decoded[0], warnings(envelope), metadata.try(&.next_cursor).presence)
    end

    # Parses the body once into the model and its envelope fields. Returns nil
    # when the body does not decode as the model, such as an error body
    # without the model's required fields.
    private def self.decode(body : String) : {M, Envelope}?
      decode(body, M)
    rescue JSON::ParseException | TypeCastError | ArgumentError
      nil
    end

    private def self.decode(body : String, type : JSON::Any.class) : {JSON::Any, Envelope}
      raw = JSON.parse(body)
      {raw, EnvelopeBody.new(raw)}
    end

    private def self.decode(body : String, type : T.class) : {T, Envelope} forall T
      type.from_api_response(body)
    end

    private def self.parse_envelope(body : String, status : Int32) : Envelope
      EnvelopeBody.from_json(body)
    rescue JSON::ParseException
      raise Error.new(success?(status) ? "invalid_response" : "http_error", status)
    end

    # True when Slack answers `ok: false` with no `error` and the model's
    # outcome flag set, such as `{"ok": false, "not_in_channel": true}`.
    private def self.flagged_outcome?(envelope : Envelope) : Bool
      envelope.error.nil? && envelope.flagged_outcome?
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

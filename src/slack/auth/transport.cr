require "http"
require "uri"
require "./errors"

module Slack::Auth
  # Feature-specific configs have no global environment reads or cross-feature requirements.
  record APIConfiguration, base_uri : URI
  record OAuthConfiguration, authorization_uri : URI, token_uri : URI,
    client_id : String, client_secret : Secret, redirect_uri : URI
  record OIDCConfiguration, discovery_uri : URI, issuer : String, client_id : String
  record TransportOptions, connect_timeout : Time::Span = 10.seconds,
    read_timeout : Time::Span = 30.seconds, write_timeout : Time::Span = 30.seconds,
    proxy_uri : URI? = nil, ca_file : String? = nil

  # Request/response contain secrets: no automatic logging or exception interpolation.
  struct TransportRequest
    getter method : String
    getter uri : URI
    getter headers : HTTP::Headers
    getter body : String?

    def initialize(@method : String, @uri : URI, @headers = HTTP::Headers.new, @body : String? = nil)
    end

    def inspect(io : IO) : Nil
      io << "Slack::Auth::TransportRequest([REDACTED])"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end
  end

  struct TransportResponse
    getter status : Int32
    getter headers : HTTP::Headers
    getter body : String

    def initialize(@status : Int32, @headers : HTTP::Headers, @body : String)
    end

    def inspect(io : IO) : Nil
      io << "Slack::Auth::TransportResponse(status=" << @status << ", [REDACTED])"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end
  end

  abstract class Transport
    # Exactly one attempt; no implicit retries/redirects of credential-bearing requests.
    # An ambiguous send raises UnknownRemoteOutcome, not retryable TransportFailure.
    abstract def execute(request : TransportRequest) : TransportResponse
  end

  abstract class TransportFactory
    abstract def build(options : TransportOptions) : Transport
  end
end

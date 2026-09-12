require "http"
require "uri"
require "./request_authorization_error"
require "./store"
require "./transport"

module Slack::Auth
  # Adds one fenced credential immediately before one request to the configured API boundary.
  class ScopedTransport < Transport
    getter reference : CredentialReference

    @configuration : APIConfiguration
    @base_path : String

    def initialize(@store : InstallationStore, @reference : CredentialReference,
                   @delegate : Transport, configuration : APIConfiguration)
      @configuration = APIConfiguration.new(URI.parse(configuration.base_uri.to_s))
      @base_path = self.class.validate_configuration(@configuration.base_uri)
    end

    def configuration : APIConfiguration
      APIConfiguration.new(URI.parse(@configuration.base_uri.to_s))
    end

    def self.validate_configuration(uri : URI) : String
      invalid_configuration unless uri.scheme.try(&.downcase) == "https"
      invalid_configuration unless uri.host
      invalid_configuration if uri.user || uri.password || uri.query || uri.fragment
      path = uri.path
      invalid_configuration unless path.ends_with?('/')
      invalid_configuration if unsafe_path?(path)
      path
    end

    def execute(request : TransportRequest) : TransportResponse
      uri = URI.parse(request.uri.to_s)
      headers = request.headers.dup
      validate_request(uri)

      token = @store.credential_for_dispatch(@reference)
      headers["Authorization"] = "Bearer #{token.value}"
      @delegate.execute(TransportRequest.new(request.method, uri, headers, request.body))
    end

    def endpoint(name : String) : URI
      invalid(:unsafe_destination) unless /\A[a-zA-Z0-9._-]+\z/.matches?(name)
      @configuration.base_uri.resolve(name)
    end

    private def validate_request(uri : URI) : Nil
      base = @configuration.base_uri
      invalid(:unsafe_destination) unless uri.scheme.try(&.downcase) == base.scheme.try(&.downcase)
      invalid(:unsafe_destination) unless uri.host.try(&.downcase) == base.host.try(&.downcase)
      invalid(:unsafe_destination) unless effective_port(uri) == effective_port(base)
      invalid(:unsafe_destination) if uri.user || uri.password || uri.fragment
      path = uri.path
      invalid(:unsafe_destination) unless path.starts_with?(@base_path) && path.size > @base_path.size
      invalid(:unsafe_destination) if self.class.unsafe_path?(path)
    end

    private def effective_port(uri : URI) : Int32?
      uri.port || (uri.scheme.try(&.downcase) == "https" ? 443 : nil)
    end

    protected def self.unsafe_path?(path : String) : Bool
      path.includes?('\\') || path.includes?('%') || path.split('/').any? { |segment| segment == "." || segment == ".." }
    end

    private def self.invalid_configuration : NoReturn
      raise RequestAuthorizationError.new(:unsafe_configuration, ErrorCode::InvalidConfiguration)
    end

    private def invalid(reason : Symbol, code : ErrorCode = ErrorCode::InvalidConfiguration) : NoReturn
      raise RequestAuthorizationError.new(reason, code)
    end
  end
end

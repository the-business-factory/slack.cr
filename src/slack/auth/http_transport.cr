require "http/client"
require "./endpoint_validator"
require "./http_connection_factory"
require "./http_response_reader"
require "./transport"
require "./write_tracking_io"

module Slack::Auth
  class HTTPTransport < Transport
    @connections : HTTPConnectionFactory
    @proxy : ProxyConfiguration?

    def initialize(options : TransportOptions = TransportOptions.new)
      @connections = HTTPConnectionFactory.new(options)
      @proxy = @connections.proxy
    end

    def execute(request : TransportRequest) : TransportResponse
      EndpointValidator.validate!(request.uri)
      validate_method!(request.method)

      connection = @connections.open(host(request.uri), port(request.uri),
        tls: request.uri.scheme.try(&.downcase) == "https")
      tracked = WriteTrackingIO.new(connection)
      execute_once(tracked, request)
    rescue error : ContractError
      raise error
    rescue
      raise ContractError.new(ErrorCode::TransportFailure)
    ensure
      close_connection(connection)
    end

    private def execute_once(tracked : WriteTrackingIO, request : TransportRequest) : TransportResponse
      headers = request_headers(request)
      implicit_compression = configure_compression(headers)
      target = request_target(request.uri)
      headers["User-Agent"] ||= "Crystal"
      HTTP::Request.new(request.method, target, headers, request.body || "").to_io(tracked)
      tracked.flush
      HTTPResponseReader.read(tracked, request.method, implicit_compression)
    rescue
      code = tracked.application_write_started? ? ErrorCode::UnknownRemoteOutcome : ErrorCode::TransportFailure
      raise ContractError.new(code)
    end

    private def configure_compression(headers : HTTP::Headers) : Bool
      {% if flag?(:without_zlib) %}
        false
      {% else %}
        return false if headers.has_key?("Accept-Encoding")

        headers["Accept-Encoding"] = "gzip, deflate"
        true
      {% end %}
    end

    private def request_headers(request : TransportRequest) : HTTP::Headers
      headers = request.headers.dup
      headers.delete("Proxy-Authorization")
      headers["Host"] = authority(request.uri)
      headers["Connection"] = "close"
      if request.uri.scheme.try(&.downcase) == "http" && (authorization = @proxy.try(&.authorization))
        headers["Proxy-Authorization"] = authorization
      end
      headers
    end

    private def request_target(uri : URI) : String
      @proxy && uri.scheme.try(&.downcase) == "http" ? uri.to_s : uri.request_target
    end

    private def authority(uri : URI) : String
      destination_host = network_host(host(uri))
      formatted_host = destination_host.includes?(':') ? "[#{destination_host}]" : destination_host
      uri_port = port(uri)
      default_port = uri.scheme.try(&.downcase) == "https" ? 443 : 80
      uri_port == default_port ? formatted_host : "#{formatted_host}:#{uri_port}"
    end

    private def port(uri : URI) : Int32
      uri.port || (uri.scheme.try(&.downcase) == "https" ? 443 : 80)
    end

    private def network_host(host : String) : String
      host.lchop('[').rchop(']')
    end

    private def host(uri : URI) : String
      uri.host || invalid!
    end

    private def close_connection(connection : IO?) : Nil
      connection.try { |io| io.close unless io.closed? }
    rescue
      nil
    end

    private def validate_method!(method : String) : Nil
      invalid! unless method.matches?(/\A[A-Z]+\z/)
    end

    private def invalid! : NoReturn
      raise ContractError.new(ErrorCode::InvalidConfiguration)
    end
  end
end

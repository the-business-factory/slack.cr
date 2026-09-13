require "http/client"
require "openssl"
require "socket"
require "./endpoint_validator"
require "./http_response_reader"
require "./proxy_configuration"
require "./transport"
require "./write_tracking_io"

module Slack::Auth
  class HTTPTransport < Transport
    @proxy : ProxyConfiguration?

    def initialize(@options : TransportOptions = TransportOptions.new)
      validate_options!
      @proxy = @options.proxy_uri.try { |uri| ProxyConfiguration.new(uri) }
    end

    def execute(request : TransportRequest) : TransportResponse
      EndpointValidator.validate!(request.uri)
      validate_method!(request.method)

      connection = open_connection(request.uri)
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

    private def open_connection(uri : URI) : IO
      proxy = @proxy
      if proxy
        socket = open_socket(network_host(proxy.host), proxy.port)
        return proxy_connection(socket, proxy, uri)
      end

      destination_host = network_host(host(uri))
      socket = open_socket(destination_host, port(uri))
      uri.scheme.try(&.downcase) == "https" ? tls_socket(socket, destination_host) : configured_socket(socket)
    rescue error : ContractError
      close_connection(socket)
      raise error
    rescue
      close_connection(socket)
      raise ContractError.new(ErrorCode::TransportFailure)
    end

    private def open_socket(host : String, port : Int32) : TCPSocket
      socket = TCPSocket.new(host, port,
        dns_timeout: @options.connect_timeout,
        connect_timeout: @options.connect_timeout)
      socket.read_timeout = @options.connect_timeout
      socket.write_timeout = @options.connect_timeout
      socket
    end

    private def proxy_connection(socket : TCPSocket, proxy : ProxyConfiguration, uri : URI) : IO
      return configured_socket(socket) if uri.scheme.try(&.downcase) == "http"

      establish_tunnel(socket, proxy, uri)
      tls_socket(socket, network_host(host(uri)))
    end

    private def establish_tunnel(socket : TCPSocket, proxy : ProxyConfiguration, uri : URI) : Nil
      authority = authority(uri)
      headers = HTTP::Headers{"Host" => authority}
      if authorization = proxy.authorization
        headers["Proxy-Authorization"] = authorization
      end
      HTTP::Request.new("CONNECT", authority, headers, "").to_io(socket)
      socket.flush
      response = HTTP::Client::Response.from_io(socket, ignore_body: true)
      raise ContractError.new(ErrorCode::TransportFailure) unless response.success?
    end

    private def tls_socket(socket : TCPSocket, host : String) : OpenSSL::SSL::Socket::Client
      tls = OpenSSL::SSL::Socket::Client.new(socket, tls_context, sync_close: true, hostname: host.rchop('.'))
      configured_socket(tls)
      tls
    end

    private def tls_context : OpenSSL::SSL::Context::Client
      context = OpenSSL::SSL::Context::Client.new
      if ca_file = @options.ca_file
        context.ca_certificates = ca_file
      end
      context
    rescue
      raise ContractError.new(ErrorCode::InvalidConfiguration)
    end

    private def configured_socket(socket : IO) : IO
      if socket.responds_to?(:read_timeout=)
        socket.read_timeout = @options.read_timeout
      end
      if socket.responds_to?(:write_timeout=)
        socket.write_timeout = @options.write_timeout
      end
      socket
    end

    private def request_headers(request : TransportRequest) : HTTP::Headers
      headers = request.headers.dup
      headers.delete("Proxy-Authorization")
      headers["Host"] = authority(request.uri, include_default_port: false)
      headers["Connection"] = "close"
      if proxy = @proxy
        if request.uri.scheme.try(&.downcase) == "http"
          if authorization = proxy.authorization
            headers["Proxy-Authorization"] = authorization
          end
        end
      end
      headers
    end

    private def request_target(uri : URI) : String
      @proxy && uri.scheme.try(&.downcase) == "http" ? uri.to_s : uri.request_target
    end

    private def authority(uri : URI, *, include_default_port : Bool = true) : String
      destination_host = network_host(host(uri))
      formatted_host = destination_host.includes?(':') ? "[#{destination_host}]" : destination_host
      uri_port = port(uri)
      default_port = uri.scheme.try(&.downcase) == "https" ? 443 : 80
      include_port = include_default_port || uri_port != default_port
      include_port ? "#{formatted_host}:#{uri_port}" : formatted_host
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

    private def validate_options! : Nil
      spans = {@options.connect_timeout, @options.read_timeout, @options.write_timeout}
      invalid! unless spans.all? { |span| span > Time::Span::ZERO }

      if ca_file = @options.ca_file
        invalid! if ca_file.empty? || !File.file?(ca_file)
        context = OpenSSL::SSL::Context::Client.new
        context.ca_certificates = ca_file
      end
    rescue error : ContractError
      raise error
    rescue
      invalid!
    end

    private def validate_method!(method : String) : Nil
      invalid! unless method.matches?(/\A[A-Z]+\z/)
    end

    private def invalid! : NoReturn
      raise ContractError.new(ErrorCode::InvalidConfiguration)
    end
  end
end

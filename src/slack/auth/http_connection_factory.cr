require "http/client"
require "openssl"
require "socket"
require "./proxy_configuration"
require "./transport"

module Slack::Auth
  # :nodoc:
  # Completes connection setup before application writes can have an unknown outcome.
  class HTTPConnectionFactory
    getter proxy : ProxyConfiguration?

    def initialize(@options : TransportOptions)
      validate_options!
      @proxy = @options.proxy_uri.try { |uri| ProxyConfiguration.new(uri) }
    end

    # The caller validates the destination and owns the returned connection.
    # Setup failures close the socket here because ownership has not transferred.
    def open(host : String, port : Int32, *, tls : Bool) : IO
      destination_host = network_host(host)
      proxy = @proxy
      socket = if proxy
                 open_socket(network_host(proxy.host), proxy.port)
               else
                 open_socket(destination_host, port)
               end
      return configured_socket(socket) unless tls

      establish_tunnel(socket, proxy, host, port) if proxy
      tls_socket(socket, destination_host)
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

    private def establish_tunnel(socket : TCPSocket, proxy : ProxyConfiguration, host : String, port : Int32) : Nil
      authority = "#{host}:#{port}"
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

    private def network_host(host : String) : String
      host.lchop('[').rchop(']')
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

    private def invalid! : NoReturn
      raise ContractError.new(ErrorCode::InvalidConfiguration)
    end
  end
end

require "socket"
require "uri"
require "./errors"

module Slack::Auth::EndpointValidator
  extend self

  def validate!(uri : URI, *, query_allowed : Bool = true) : Nil
    scheme = required_scheme(uri)
    host = required_host(uri)
    validate_host!(host)
    validate_components!(uri, query_allowed)
    validate_port!(uri.port)
    validate_scheme!(scheme, host)
  rescue URI::Error
    invalid!
  end

  # URI hosts are already decoded. Validate their syntax without resolving them.
  def validate_host!(host : String) : Nil
    if host.starts_with?('[') && host.ends_with?(']')
      address = host[1...-1]
      invalid! if address.includes?('%') || !Socket::IPAddress.valid_v6?(address)
    elsif host.matches?(/\A[0-9.]+\z/)
      invalid! unless Socket::IPAddress.valid_v4?(host)
    else
      name = host.rchop('.')
      invalid! unless name.bytesize.in?(1..253)
      name.split('.').each do |label|
        invalid! unless label.bytesize.in?(1..63)
        invalid! unless label.matches?(/\A[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\z/)
      end
    end
  end

  def loopback?(host : String) : Bool
    normalized = host.downcase.rchop('.').lchop('[').rchop(']')
    return true if normalized == "localhost" || normalized == "::1"

    parts = normalized.split('.')
    return false unless parts.size == 4 && parts.all? { |part| octet?(part) }

    parts.first == "127"
  end

  private def validate_components!(uri : URI, query_allowed : Bool) : Nil
    invalid! unless uri.user.nil? && uri.password.nil? && uri.fragment.nil?
    invalid! unless query_allowed || uri.query.nil?
    invalid! unless uri.path.empty? || uri.path.starts_with?('/')
    validate_uri_component!(uri.path)
    uri.query.try { |query| validate_uri_component!(query) }
  end

  private def validate_uri_component!(component : String) : Nil
    bytes = component.to_slice
    index = 0
    while index < bytes.size
      byte = bytes[index]
      invalid! if byte <= 0x20_u8 || byte == 0x7f_u8

      if byte == '%'.ord.to_u8
        invalid! unless index + 2 < bytes.size
        invalid! unless ascii_hex_digit?(bytes[index + 1]) && ascii_hex_digit?(bytes[index + 2])
        index += 3
      else
        index += 1
      end
    end
  end

  private def ascii_hex_digit?(byte : UInt8) : Bool
    byte.in?(0x30_u8..0x39_u8) || byte.in?(0x41_u8..0x46_u8) || byte.in?(0x61_u8..0x66_u8)
  end

  private def validate_port!(port : Int32?) : Nil
    invalid! if port && !(1..65_535).includes?(port)
  end

  private def validate_scheme!(scheme : String, host : String) : Nil
    case scheme
    when "https"
      nil
    when "http"
      invalid! unless loopback?(host)
    else
      invalid!
    end
  end

  private def required_scheme(uri : URI) : String
    uri.scheme.try(&.downcase) || invalid!
  end

  private def required_host(uri : URI) : String
    host = uri.host
    invalid! if host.nil? || host.empty?
    host
  end

  private def octet?(part : String) : Bool
    value = part.to_i?
    !part.empty? && value && value.in?(0..255) ? true : false
  end

  private def invalid! : NoReturn
    raise Slack::Auth::ContractError.new(Slack::Auth::ErrorCode::InvalidConfiguration)
  end
end

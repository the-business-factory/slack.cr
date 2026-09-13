require "http/client"
require "mime/media_type"
require "./transport"

{% unless flag?(:without_zlib) %}
  require "compress/zlib"
{% end %}

module Slack::Auth
  # Reads one response in wire order so framing is complete before content or
  # charset decoding changes the representation bytes.
  class HTTPResponseReader
    def self.read(io : IO, method : String, implicit_compression : Bool) : TransportResponse
      response = read_final_response(io)
      status = response.status
      headers = response.headers
      return TransportResponse.new(status.code, headers, "") unless body_expected?(method, status)

      body = read_representation(io, headers)
      body = decode_content(body, headers) if implicit_compression
      body = decode_charset(body, headers) unless headers.has_key?("Content-Encoding")
      TransportResponse.new(status.code, headers, body)
    end

    private def self.read_final_response(io : IO) : HTTP::Client::Response
      loop do
        response = HTTP::Client::Response.from_io(io, ignore_body: true, decompress: false)
        # A 101 response is terminal because the connection changes protocols.
        return response unless response.status.informational? && response.status.code != 101
      end
    end

    private def self.read_representation(io : IO, headers : HTTP::Headers) : String
      transfer_codings = parse_codings(headers["Transfer-Encoding"]?)
      content_length = transfer_codings ? nil : HTTP.content_length(headers)
      body_io = if transfer_codings
                  unless transfer_codings == ["chunked"]
                    raise IO::Error.new("Unsupported HTTP transfer-coding sequence")
                  end
                  HTTP::ChunkedContent.new(io)
                elsif content_length
                  HTTP::FixedLengthContent.new(io, content_length)
                else
                  HTTP::UnknownLengthContent.new(io)
                end

      body = body_io.gets_to_end
      if content_length && body.bytesize.to_u64 != content_length
        raise IO::EOFError.new("Incomplete HTTP response body")
      end
      body
    end

    private def self.decode_content(body : String, headers : HTTP::Headers) : String
      {% if flag?(:without_zlib) %}
        body
      {% else %}
        codings = parse_codings(headers["Content-Encoding"]?)
        return body unless codings && codings.all? { |coding| coding == "gzip" || coding == "deflate" }

        decoded = body
        codings.reverse_each do |coding|
          decoded = case coding
                    when "gzip"
                      Compress::Gzip::Reader.open(IO::Memory.new(decoded)) do |reader|
                        reader.gets_to_end
                      end
                    when "deflate"
                      decode_deflate(decoded)
                    else
                      decoded
                    end
        end
        headers.delete("Content-Encoding")
        headers.delete("Content-Length")
        decoded
      {% end %}
    end

    {% unless flag?(:without_zlib) %}
      private def self.decode_deflate(body : String) : String
        # HTTP deflate uses zlib. Select it by the compression-method byte so a
        # damaged header, checksum, or truncated stream cannot trigger a retry.
        # Other streams retain the existing raw DEFLATE compatibility path.
        first = body.byte_at?(0)
        reader = if first && (first & 0x0f) == 8
                   Compress::Zlib::Reader.new(IO::Memory.new(body))
                 else
                   Compress::Deflate::Reader.new(IO::Memory.new(body))
                 end
        reader.gets_to_end
      ensure
        reader.try(&.close)
      end
    {% end %}

    private def self.parse_codings(value : String?) : Array(String)?
      value.try do |header|
        header.split(',').map(&.strip.downcase)
      end
    end

    private def self.decode_charset(body : String, headers : HTTP::Headers) : String
      content_type = headers["Content-Type"]?
      return body unless content_type
      mime_type = MIME::MediaType.parse?(content_type)
      return body unless mime_type
      charset = mime_type["charset"]?
      return body if !charset || charset == "utf-8"

      source = IO::Memory.new(body)
      source.set_encoding(charset, invalid: :skip)
      source.gets_to_end
    end

    private def self.body_expected?(method : String, status : HTTP::Status) : Bool
      method != "HEAD" && HTTP::Client::Response.mandatory_body?(status)
    end
  end
end

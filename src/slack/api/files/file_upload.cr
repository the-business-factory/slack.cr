require "http"
require "uri"
require "../../auth/transport"

module Slack::Api
  # Uploads one file with Slack's three-step external upload flow and returns
  # the completed files. See https://docs.slack.dev/messaging/working-with-files/#uploading-files.
  #
  # ```
  # upload = Slack::Api::FileUpload.new("notes.txt", IO::Memory.new("Release notes"),
  #   share: Slack::Api::FileShare.new(channel_id: "C123"))
  # files = upload.run(client, Slack::Auth::HTTPTransportFactory.new.build(Slack::Auth::TransportOptions.new))
  # ```
  #
  # The constructor reads *content* to its end once and keeps all bytes in
  # memory. The caller still owns and closes the IO.
  #
  # `#run` calls `files.getUploadURLExternal` through *client*, then POSTs the
  # bytes with `Content-Type: application/octet-stream` to the returned
  # `upload_url` through *upload_transport*, then calls
  # `files.completeUploadExternal`. The upload URL is on a different host
  # (`files.slack.com`) and needs no token, so the byte POST carries no
  # `Authorization` header. Pass a raw transport, not a scoped transport:
  # `Auth::ScopedTransport` rejects any host other than the API base URI.
  struct FileUpload
    getter filename : String
    getter title : String?
    getter alt_txt : String?
    getter snippet_type : String?
    getter share : FileShare?
    @content : String

    def initialize(@filename : String, content : IO | Bytes, *, @title : String? = nil, @alt_txt : String? = nil,
                   @snippet_type : String? = nil, @share : FileShare? = nil)
      # A String holds arbitrary bytes; `TransportRequest#body` is a String.
      @content = content.is_a?(IO) ? content.gets_to_end : String.new(content)
    end

    # The file size in bytes.
    def length : Int32
      @content.bytesize
    end

    # Issues of the upload URL request and the share. `#run` sends nothing while issues remain.
    def validate : Array(UI::ValidationIssue)
      issues = upload_url_request.validate
      @share.try { |share| issues.concat(share.validate) }
      issues
    end

    def validate! : Nil
      issues = validate
      raise UI::ValidationError.new(issues) unless issues.empty?
    end

    # Runs the three steps. A failed step raises and stops the flow:
    # `Api::Error` for a Slack failure or a non-success byte upload status
    # (`http_error` with `http_status`), and transport errors unchanged. An
    # error from the completion step does not prove that Slack did not share the
    # file: `Auth::ContractError` with `UnknownRemoteOutcome` and Slack's `internal_error` or
    # `fatal_error` can follow a partial or full success. Do not treat such an
    # error as proof that running the whole upload again is safe.
    def run(client : Client, upload_transport : Auth::Transport) : Array(Models::File)
      validate!
      destination = client.call(upload_url_request)
      send_bytes(upload_transport, destination.upload_url)
      completion = FilesCompleteUploadExternal.new([FileReference.new(destination.file_id, @title)], @share)
      client.call(completion).files
    end

    # Shows the filename and size, not the file content.
    def inspect(io : IO) : Nil
      io << "#<Slack::Api::FileUpload filename=" << @filename.inspect << " length=" << length << '>'
    end

    private def upload_url_request : FilesGetUploadURLExternal
      FilesGetUploadURLExternal.new(@filename, length, @alt_txt, @snippet_type)
    end

    private def send_bytes(transport : Auth::Transport, upload_url : String) : Nil
      uri = upload_uri(upload_url)
      headers = HTTP::Headers{"Content-Type" => "application/octet-stream"}
      response = transport.execute(Auth::TransportRequest.new("POST", uri, headers, @content))
      raise Error.new("http_error", response.status) unless 200 <= response.status < 300
    end

    # Library policy: send file bytes only over HTTPS to an absolute URL.
    private def upload_uri(upload_url : String) : URI
      uri = URI.parse(upload_url)
      raise Error.new("invalid_response", 200) unless uri.scheme.try(&.downcase) == "https" && uri.host.presence
      uri
    end
  end
end

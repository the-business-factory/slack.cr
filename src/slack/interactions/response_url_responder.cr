# Posts messages to one `response_url` from a slash command or an interaction
# payload. Slack accepts up to five posts within 30 minutes of the payload.
# Still acknowledge the request itself within three seconds.
#
# The URL grants posting without a token, so `inspect` and errors redact it.
# Each post is one attempt through the given transport; this type does not
# retry, count uses, or track expiry.
#
# ```
# responder = Slack::Interactions::ResponseUrlResponder.new(command.response_url)
# responder.post(Slack::Auth::HTTPTransport.new, Slack::Interactions::ResponseUrlMessage.new(text: "Done."))
# ```
struct Slack::Interactions::ResponseUrlResponder
  @uri : URI

  # Raises `Auth::ContractError` (`InvalidConfiguration`) unless the URL is an
  # absolute HTTPS URL.
  def initialize(response_url : String)
    @uri = URI.parse(response_url)
    Slack::Auth::EndpointValidator.validate!(@uri)
  end

  # Raises `ResponseUrlError` for a non-2xx status. Transport errors keep
  # their `Auth::ContractError` classification (`TransportFailure` or
  # `UnknownRemoteOutcome`).
  def post(transport : Slack::Auth::Transport, message : ResponseUrlMessage) : Nil
    body = message.to_json
    headers = HTTP::Headers{"Content-Type" => "application/json"}
    response = transport.execute(Slack::Auth::TransportRequest.new("POST", @uri, headers, body))
    raise ResponseUrlError.new(response.status) unless (200..299).includes?(response.status)
  end

  def inspect(io : IO) : Nil
    io << "Slack::Interactions::ResponseUrlResponder([REDACTED])"
  end

  def to_s(io : IO) : Nil
    inspect(io)
  end
end

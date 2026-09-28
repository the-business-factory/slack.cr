require "http"
require "json"
require "log"
require "../auth/errors"
require "../auth/transport"
require "../auth/http_transport_factory"
require "./rate_limits"
require "./request"
require "./response"
require "./generic_request"
require "./pagination/paginated"
require "./pagination/page"

module Slack::Api
  # Sends Web API requests with one token, one API base URI, and one transport.
  #
  # ```
  # client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"])
  # client.call(Slack::Api::ChatDelete.new(channel: "C123", ts: "1710000000.000100"))
  # ```
  #
  # Each call waits for local per-method pacing, then makes exactly one transport
  # attempt. The client does not retry. Transport errors (`Auth::ContractError`
  # with `TransportFailure` or `UnknownRemoteOutcome`) pass through unchanged.
  # Without a token, the client sends no `Authorization` header, so a scoped
  # transport such as the one in `Auth::RequestContext` can add the credential.
  class Client
    Log = ::Log.for("slack.api")

    @token : Auth::Secret?
    @rate_limits = RateLimits.new

    def initialize(*, token : String | Auth::Secret?,
                   @configuration : Auth::APIConfiguration = Auth::APIConfiguration.default,
                   @transport : Auth::Transport = Auth::HTTPTransportFactory.new.build(Auth::TransportOptions.new))
      @token = secret(token)
    end

    # Validates, encodes, and sends *request*, then returns its response model.
    # Raises `UI::ValidationError` before dispatch and `Api::Error` for Slack failures.
    def call(request : Request(M)) : M forall M
      execute(request).model
    end

    # Calls *request* and yields each `Page` in order. After each page, it sends
    # the request again with the page's `next_cursor`, until Slack returns an
    # empty, null, or missing cursor. Break from the block to stop early.
    #
    # ```
    # client.each_page(Slack::Api::ConversationsMembers.new("C123", limit: 200)) do |page|
    #   page.model.members.each { |user_id| puts user_id }
    # end
    # ```
    #
    # Each page is one `#call`: local pacing applies and errors, including
    # `RateLimited`, raise from the loop. The client does not wait and retry.
    def each_page(request : Paginated, &) : Nil
      loop do
        response = execute(request)
        next_cursor = response.next_cursor
        yield Page.new(response.model, next_cursor)
        break unless next_cursor
        request = request.with_cursor(next_cursor)
      end
    end

    # Calls any Web API method with form fields and returns the raw JSON response.
    # Strings are sent unchanged, other values as JSON text, and nil values are omitted.
    # *tier* selects local pacing; use the tier on the method's reference page.
    #
    # ```
    # emoji = client.call("emoji.list", {include_categories: true})
    # ```
    def call(method : String, params : NamedTuple | Hash = NamedTuple.new,
             tier : RateLimitTier = RateLimitTier::Tier2) : JSON::Any
      call(GenericRequest.new(method, params, tier))
    end

    # Starts a streamed message and returns its `MessageStream`.
    # See `ChatStartStream` for the request fields.
    def start_stream(request : ChatStartStream) : MessageStream
      message = call(request)
      MessageStream.new(message.channel, message.ts)
    end

    def inspect(io : IO) : Nil
      io << "#<Slack::Api::Client token=" << (@token ? "[REDACTED]" : "none")
      io << " base_uri=" << @configuration.base_uri << '>'
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end

    private def execute(request : Request(M)) : Response(M) forall M
      request.validate!
      body = request.body
      uri = @configuration.endpoint(request.method_path)
      @rate_limits.wait(request.method_path, request.tier)
      transport_response = @transport.execute(
        Auth::TransportRequest.new("POST", uri, headers(request.content_type), body))
      response = Response(M).parse(transport_response)
      log_warnings(request.method_path, response.warnings)
      response
    end

    private def headers(content_type : String) : HTTP::Headers
      headers = HTTP::Headers{"Content-Type" => content_type}
      if token = @token
        headers["Authorization"] = "Bearer #{token.value}"
      end
      headers
    end

    private def log_warnings(method_path : String, warnings : Array(String)) : Nil
      return if warnings.empty?
      codes = warnings.map { |code| Error::SAFE_CODE.matches?(code) ? code : "unrecognized" }
      Log.warn { "#{method_path} returned warnings: #{codes.join(", ")}" }
    end

    private def secret(token : String | Auth::Secret?) : Auth::Secret?
      value = token.is_a?(Auth::Secret) ? token.value : token
      return if value.nil?
      raise ArgumentError.new("API token must not be blank") if value.blank?
      Auth::Secret.new(value)
    end
  end
end

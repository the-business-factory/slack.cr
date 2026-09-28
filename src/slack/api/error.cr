module Slack::Api
  # A Web API call that Slack did not complete successfully.
  #
  # `code` is Slack's `error` value, or one of these library codes:
  # `invalid_response` (the body is not a usable Slack response) and
  # `http_error` (a non-success HTTP status without a Slack error).
  # The message never includes the response body, headers, or token.
  class Error < Exception
    SAFE_CODE = /\A[a-z0-9_]{1,64}\z/

    getter code : String
    getter http_status : Int32
    getter retry_after : Time::Span?
    @messages : Array(String)

    def initialize(@code : String, @http_status : Int32, messages : Array(String) = [] of String,
                   @retry_after : Time::Span? = nil)
      @messages = messages.dup
      # Slack error names are short identifiers. Keep any other remote text out of the message.
      shown = SAFE_CODE.matches?(@code) ? @code : "unrecognized error"
      super("Slack API error: #{shown} (HTTP #{@http_status})")
    end

    # Details from `response_metadata.messages`, such as invalid argument descriptions.
    def messages : Array(String)
      @messages.dup
    end
  end
end

require "../auth/errors"
require "../errors/auth"

# Safe response failures remain catchable as Errors::Auth.
class Slack::Auth::ResponseError < Slack::Errors::Auth
  getter code : ErrorCode
  getter http_status : Int32
  getter retry_after : Time::Span?
  getter slack_error : String?

  def initialize(@code : ErrorCode = ErrorCode::InvalidResponse, @http_status : Int32 = 200,
                 @retry_after : Time::Span? = nil, @slack_error : String? = nil)
    super("OAuth response failure: #{@code}")
  end
end

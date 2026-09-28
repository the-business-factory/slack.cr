# Events API delivery metadata from the HTTP request headers.
#
# Slack retries a delivery up to three times when the app does not return
# HTTP 2xx within three seconds. A retry carries `X-Slack-Retry-Num` (1 to 3)
# and `X-Slack-Retry-Reason`, for example `http_timeout`. The first delivery
# carries neither header. Slack does not sign these headers.
#
# ```
# delivery = Slack::Events::Delivery.from_headers(request.headers)
# return acknowledge if delivery.retry? && already_processed?(event_id)
# ```
struct Slack::Events::Delivery
  RETRY_NUM_HEADER    = "X-Slack-Retry-Num"
  RETRY_REASON_HEADER = "X-Slack-Retry-Reason"

  # Add this header with `NO_RETRY_VALUE` to a non-2xx response to ask Slack
  # not to retry the delivery. This library does not send responses.
  NO_RETRY_HEADER = "X-Slack-No-Retry"
  NO_RETRY_VALUE  = "1"

  # Retry attempt number, or nil on the first delivery. A value that is not
  # a positive integer reads as nil.
  getter retry_num : Int32?

  # Slack's retry reason, kept as sent so that new reasons stay readable.
  getter retry_reason : String?

  def self.from_headers(headers : HTTP::Headers) : self
    new(retry_num(headers[RETRY_NUM_HEADER]?), headers[RETRY_REASON_HEADER]?)
  end

  def initialize(@retry_num : Int32? = nil, @retry_reason : String? = nil)
  end

  # Returns true when either retry header is present.
  def retry? : Bool
    !(@retry_num.nil? && @retry_reason.nil?)
  end

  private def self.retry_num(value : String?) : Int32?
    number = value.try(&.to_i?)
    number if number && number > 0
  end
end

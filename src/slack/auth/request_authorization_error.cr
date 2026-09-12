require "./errors"

module Slack::Auth
  # The reason is an allowlisted symbol and never contains payload or response data.
  class RequestAuthorizationError < ContractError
    getter reason : Symbol

    def initialize(@reason : Symbol, code : ErrorCode = ErrorCode::InvalidIdentity,
                   http_status : Int32? = nil, retry_after : Time::Span? = nil)
      super(code, http_status, retry_after)
    end
  end
end

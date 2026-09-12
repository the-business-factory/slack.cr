require "../auth/errors"

module Slack::Api
  class AuthTestError < Slack::Auth::ContractError
    getter reason : Symbol

    def initialize(@reason : Symbol, code : Slack::Auth::ErrorCode = Slack::Auth::ErrorCode::InvalidResponse,
                   http_status : Int32? = nil, retry_after : Time::Span? = nil)
      super(code, http_status, retry_after)
    end
  end
end

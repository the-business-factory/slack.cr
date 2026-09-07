module Slack::Auth
  enum ErrorCode
    InvalidConfiguration
    InvalidIdentity
    InvalidState
    MissingInstallation
    MissingGrant
    Conflict
    RefreshBusy
    ReauthorizationRequired
    UnknownRemoteOutcome
    PersistenceFailure
    TransportFailure
    InvalidResponse
    VerificationFailed
  end

  # Only allowlisted metadata belongs here; never attach a raw response or cause.
  class ContractError < Exception
    getter code : ErrorCode
    getter http_status : Int32?
    getter retry_after : Time::Span?

    def initialize(@code : ErrorCode, @http_status : Int32? = nil, @retry_after : Time::Span? = nil)
      super("Authentication failure: #{@code}")
    end
  end

  # Secret values require explicit access and cannot leak through nested inspect.
  struct Secret
    getter value : String

    def initialize(@value : String)
      raise ContractError.new(ErrorCode::InvalidConfiguration) if @value.empty?
    end

    def inspect(io : IO) : Nil
      io << "[REDACTED]"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end
  end
end

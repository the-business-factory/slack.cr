require "./store"

module Slack::Auth
  # Keep this value secure until local recovery succeeds or the lease expires.
  # It is not permission to repeat the remote refresh request.
  struct PendingRotation
    getter lease : RefreshLease
    getter replacement : Grant

    def initialize(@lease : RefreshLease, @replacement : Grant)
    end

    def inspect(io : IO) : Nil
      io << "Slack::Auth::PendingRotation([REDACTED])"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end
  end
end

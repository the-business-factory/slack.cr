require "./pending_rotation"

module Slack::Auth
  class RotationPersistenceError < ContractError
    getter pending : PendingRotation

    def initialize(@pending : PendingRotation)
      super(ErrorCode::PersistenceFailure)
    end
  end
end

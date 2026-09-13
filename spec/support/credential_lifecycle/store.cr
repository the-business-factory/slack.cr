require "../request_authorizer/fakes"

module CredentialLifecycleSupport
  # One-shot hooks model an atomic competing write immediately before cleanup CAS.
  class Store < RequestAuthorizerSupport::Store
    property before_mutation : Proc(Nil)?
    property mutation_failure : Slack::Auth::ErrorCode?
    getter mutation_count : Int32 = 0

    def invalidate(key : Slack::Auth::InstallationKey, grant : Slack::Auth::GrantKey,
                   expected : Slack::Auth::Version) : Slack::Auth::InstallationRecord
      run_hook
      super(key, grant, expected)
    end

    def delete(key : Slack::Auth::InstallationKey, expected : Slack::Auth::Version) : Slack::Auth::InstallationRecord
      run_hook
      super(key, expected)
    end

    private def run_hook : Nil
      @mutation_count += 1
      hook = @before_mutation
      @before_mutation = nil
      hook.try(&.call)
      if code = @mutation_failure
        raise Slack::Auth::ContractError.new(code)
      end
    end
  end
end

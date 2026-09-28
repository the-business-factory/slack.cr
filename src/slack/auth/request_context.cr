require "../api"
require "./scoped_transport"

module Slack::Auth
  # Request-local authorization state. It retains a version fence, never a reusable token.
  class RequestContext
    getter query : InstallationQuery
    getter reference : CredentialReference
    getter transport : ScopedTransport
    # Web API client over `transport`. It holds no token: the scoped transport
    # checks the fenced credential immediately before each send.
    getter client : Slack::Api::Client

    @expected_subject_id : String

    def initialize(@query : InstallationQuery, @reference : CredentialReference,
                   store : InstallationStore, transport : Transport, configuration : APIConfiguration)
      raise RequestAuthorizationError.new(:reference_mismatch) unless @reference.query == @query
      @expected_subject_id = selected_subject(store)
      @transport = ScopedTransport.new(store, @reference, transport, configuration)
      @client = Slack::Api::Client.new(token: nil, configuration: @transport.configuration, transport: @transport)
    end

    def dispatch(method : String, endpoint : String, headers : HTTP::Headers = HTTP::Headers.new,
                 body : String? = nil) : TransportResponse
      @transport.execute(TransportRequest.new(method, @transport.endpoint(endpoint), headers, body))
    end

    def auth_test : Slack::Models::Auth::Test
      result = begin
        @client.call(Slack::Api::AuthTest.new)
      rescue error : Slack::Api::Error
        raise auth_test_failure(error)
      end
      validate_identity(result)
      result
    end

    # Keeps the auth contract: only allowlisted metadata, never Slack's messages.
    private def auth_test_failure(error : Slack::Api::Error) : ContractError
      code = case error.code
             when "invalid_auth", "token_revoked", "account_inactive"
               ErrorCode::ReauthorizationRequired
             else
               ErrorCode::InvalidResponse
             end
      ContractError.new(code, error.http_status, error.retry_after)
    end

    private def validate_identity(result : Slack::Models::Auth::Test) : Nil
      owner = @query.owner
      unless result.is_enterprise_install.nil?
        mismatch unless result.is_enterprise_install == owner.kind.organization?
      end
      if owner.kind.organization?
        mismatch unless result.enterprise_id == owner.enterprise_id
      else
        mismatch unless result.team_id == owner.team_id
        if enterprise_id = owner.enterprise_id
          mismatch unless result.enterprise_id == enterprise_id
        end
      end
      mismatch unless result.user_id == @expected_subject_id
    end

    private def selected_subject(store : InstallationStore) : String
      record = store.fetch(@query.owner) || raise ContractError.new(:missing_installation)
      raise ContractError.new(:missing_installation) if record.deleted?
      stored_grant = record.grant(@query.grant)
      unless record.key == @query.owner && stored_grant &&
             record.version.generation == @reference.generation &&
             stored_grant.revision == @reference.grant_revision
        raise ContractError.new(:conflict)
      end
      subject_id = stored_grant.grant.subject_id
      if @query.grant.kind.user? && subject_id != @query.grant.user_id
        raise ContractError.new(:invalid_identity)
      end
      subject_id
    end

    private def mismatch : NoReturn
      raise RequestAuthorizationError.new(:identity_mismatch, ErrorCode::InvalidResponse)
    end
  end
end

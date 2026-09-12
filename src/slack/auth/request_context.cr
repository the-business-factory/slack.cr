require "../api/endpoints/auth_test"
require "./scoped_transport"

module Slack::Auth
  # Request-local authorization state. It retains a version fence, never a reusable token.
  class RequestContext
    getter query : InstallationQuery
    getter reference : CredentialReference
    getter transport : ScopedTransport

    @expected_subject_id : String

    def initialize(@query : InstallationQuery, @reference : CredentialReference,
                   store : InstallationStore, transport : Transport, configuration : APIConfiguration)
      raise RequestAuthorizationError.new(:reference_mismatch) unless @reference.query == @query
      @expected_subject_id = selected_subject(store)
      @transport = ScopedTransport.new(store, @reference, transport, configuration)
    end

    def dispatch(method : String, endpoint : String, headers : HTTP::Headers = HTTP::Headers.new,
                 body : String? = nil) : TransportResponse
      @transport.execute(TransportRequest.new(method, @transport.endpoint(endpoint), headers, body))
    end

    def auth_test : Slack::Models::Auth::Test
      result = Slack::Api::AuthTest.new(@transport, @transport.configuration).call
      validate_identity(result)
      result
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
        mismatch unless result.enterprise_id == owner.enterprise_id if owner.enterprise_id
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

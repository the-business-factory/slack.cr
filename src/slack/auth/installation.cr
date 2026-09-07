require "./errors"

module Slack::Auth
  enum InstallationKind
    Workspace
    Organization
  end

  struct InstallationKey
    getter app_id : String
    getter enterprise_id : String?
    getter team_id : String?
    getter kind : InstallationKind

    def initialize(@app_id : String, @kind : InstallationKind, @enterprise_id : String? = nil, @team_id : String? = nil)
      invalid = @app_id.empty? || @enterprise_id.try(&.empty?) || @team_id.try(&.empty?)
      invalid ||= @kind.workspace? ? @team_id.nil? : (@enterprise_id.nil? || !@team_id.nil?)
      raise ContractError.new(ErrorCode::InvalidIdentity) if invalid
    end
  end

  enum TokenKind
    Bot
    User
  end

  struct GrantKey
    getter kind : TokenKind
    getter user_id : String?

    def initialize(@kind : TokenKind, @user_id : String? = nil)
      if @kind.bot? ? !@user_id.nil? : (@user_id.nil? || @user_id.try(&.empty?))
        raise ContractError.new(ErrorCode::InvalidIdentity)
      end
    end
  end

  struct Grant
    getter subject_id : String
    getter access_token : Secret
    getter refresh_token : Secret?
    getter expires_at : Time?
    @scopes : Array(String)

    def initialize(@subject_id : String, @access_token : Secret, scopes : Array(String),
                   @expires_at : Time? = nil, @refresh_token : Secret? = nil)
      raise ContractError.new(ErrorCode::InvalidIdentity) if @subject_id.empty?
      @scopes = scopes.dup
    end

    def scopes : Array(String)
      @scopes.dup
    end
  end

  record IncomingWebhook, url : Secret, channel_id : String, configuration_url : Secret? = nil
  record Version, generation : Int64, revision : Int64
  record StoredGrant, grant : Grant, revision : Int64

  # A patch contains only grants received in this exchange; omitted grants survive.
  struct InstallationPatch
    getter bot : Grant?
    getter webhook : IncomingWebhook?
    @users : Hash(String, Grant)

    def initialize(@bot : Grant? = nil, users : Hash(String, Grant) = {} of String => Grant,
                   @webhook : IncomingWebhook? = nil)
      users.each do |id, grant|
        raise ContractError.new(ErrorCode::InvalidIdentity) if id.empty? || id != grant.subject_id
      end
      @users = users.dup
    end

    def users : Hash(String, Grant)
      @users.dup
    end
  end

  struct InstallationRecord
    getter key : InstallationKey
    getter version : Version
    getter bot : StoredGrant?
    getter webhook : IncomingWebhook?
    getter? deleted : Bool
    @users : Hash(String, StoredGrant)

    def initialize(@key : InstallationKey, @version : Version, @bot : StoredGrant? = nil,
                   users : Hash(String, StoredGrant) = {} of String => StoredGrant,
                   @webhook : IncomingWebhook? = nil, @deleted : Bool = false)
      @users = users.dup
    end

    def users : Hash(String, StoredGrant)
      @users.dup
    end

    def grant(key : GrantKey) : StoredGrant?
      key.kind.bot? ? @bot : @users[key.user_id]?
    end
  end

  # owner must come from verified/trusted routing, never inferred from actor/visible team.
  record InstallationQuery, owner : InstallationKey, grant : GrantKey,
    actor_user_id : String? = nil, visible_team_id : String? = nil

  # Request-local references contain a fence, not a cached reusable access token.
  record CredentialReference, query : InstallationQuery, generation : Int64, grant_revision : Int64
end

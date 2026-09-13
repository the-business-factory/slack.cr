require "../../slack"
require "./query_extractor"
require "./store"

module Slack::Auth
  # A verified event and its original store fences. Retain this object for retries.
  # Construction verifies HTTP bytes before parsing or accessing the store.
  class PreparedLifecycleDelivery
    getter event_id : String
    getter owner : InstallationKey
    getter version : Version?
    getter? uninstall : Bool
    @targets : Hash(GrantKey, Int64)

    def initialize(request : HTTP::Request, expected_app_id : String, @store : InstallationStore,
                   selected_owner : InstallationKey? = nil, clock : Proc(Time) = -> { Time.utc })
      body = Slack::Webhooks::VerifiedRequest.new(request, clock).verify!.body
      envelope = parse(body)
      invalid(:invalid_payload) if envelope.type != "event_callback" || envelope.event_id.empty?
      invalid(:app_mismatch) if envelope.api_app_id != expected_app_id || expected_app_id.empty?
      event = envelope.event
      invalid(:unsupported_lifecycle_event) unless event.is_a?(Slack::Events::AppUninstalled) || event.is_a?(Slack::Events::TokensRevoked)
      validate_targets(event)
      @event_id = envelope.event_id
      @uninstall = event.is_a?(Slack::Events::AppUninstalled)
      @owner = resolve_owner(envelope, expected_app_id, selected_owner)
      if @owner.kind.workspace? && (team_id = envelope.team_id)
        invalid(:conflicting_owner) unless team_id == @owner.team_id
      end
      record = @store.fetch(@owner)
      @version = record.try(&.version)
      @targets = targets(event, record)
    end

    def targets : Hash(GrantKey, Int64)
      @targets.dup
    end

    def prepared_for?(store : InstallationStore) : Bool
      @store.same?(store)
    end

    def inspect(io : IO) : Nil
      io << "#<Slack::Auth::PreparedLifecycleDelivery>"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end

    private def parse(body : String) : Slack::VerifiedEvent
      Slack::VerifiedEvent.from_json(body)
    rescue JSON::ParseException | JSON::SerializableError
      invalid(:invalid_payload)
    end

    private def resolve_owner(envelope : Slack::VerifiedEvent, app_id : String,
                              selected : InstallationKey?) : InstallationKey
      unless envelope.authorizations.empty?
        return QueryExtractor.new(app_id).extract(envelope, GrantKey.new(:bot), selected).owner
      end

      # Lifecycle examples can omit authorizations. Only trusted route selection
      # can supply the complete key; a workspace ID alone cannot supply its enterprise.
      owner = selected || invalid(:missing_owner)
      invalid(:app_mismatch) unless owner.app_id == app_id
      invalid(:owner_not_authorized) unless owner.kind.workspace? && owner.team_id == envelope.team_id
      owner
    end

    private def validate_targets(event : Slack::Event) : Nil
      return unless event.is_a?(Slack::Events::TokensRevoked)
      invalid(:empty_id) if event.tokens.oauth.any?(&.empty?) || event.tokens.bot.any?(&.empty?)
    end

    private def targets(event : Slack::Event, record : InstallationRecord?) : Hash(GrantKey, Int64)
      result = {} of GrantKey => Int64
      return result unless event.is_a?(Slack::Events::TokensRevoked) && record
      return result if record.deleted?
      event.tokens.oauth.each do |id|
        key = GrantKey.new(:user, id)
        if grant = record.grant(key)
          result[key] = grant.revision
        end
      end
      if bot = record.bot
        result[GrantKey.new(:bot)] = bot.revision if event.tokens.bot.includes?(bot.grant.subject_id)
      end
      result
    end

    private def invalid(reason : Symbol) : NoReturn
      raise RequestAuthorizationError.new(reason)
    end
  end
end

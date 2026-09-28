require "./verified_lifecycle_event"
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
                   verifier : Slack::Webhooks::Verifier, selected_owner : InstallationKey? = nil)
      verified = VerifiedLifecycleEvent.new(request, expected_app_id, verifier, selected_owner)
      @event_id = verified.event_id
      @uninstall = verified.uninstall?
      @owner = verified.owner
      record = @store.fetch(@owner)
      @version = record.try(&.version)
      @targets = capture_targets(verified.event, record)
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

    private def capture_targets(event : Slack::Event,
                                record : InstallationRecord?) : Hash(GrantKey, Int64)
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
  end
end

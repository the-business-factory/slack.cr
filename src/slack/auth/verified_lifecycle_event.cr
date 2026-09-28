require "../../slack"
require "./query_extractor"

module Slack::Auth
  # :nodoc:
  # Verifies and decodes a lifecycle request without accessing installation storage.
  class VerifiedLifecycleEvent
    getter event_id : String
    getter owner : InstallationKey
    getter event : Slack::Event

    # Verifies the request bytes before it parses them.
    def self.new(request : HTTP::Request, expected_app_id : String,
                 verifier : Slack::Webhooks::Verifier, selected_owner : InstallationKey? = nil) : self
      body = verifier.verify(request).body
      new(parse(body), expected_app_id, selected_owner)
    end

    # Takes an envelope that trusted application routing decoded from verified bytes.
    def initialize(envelope : Slack::VerifiedEvent, expected_app_id : String,
                   selected_owner : InstallationKey? = nil)
      @event = validate_event(envelope, expected_app_id)
      @event_id = envelope.event_id
      @owner = resolve_owner(envelope, expected_app_id, selected_owner)
      if @owner.kind.workspace? && (team_id = envelope.team_id)
        invalid(:conflicting_owner) unless team_id == @owner.team_id
      end
    end

    def uninstall? : Bool
      @event.is_a?(Slack::Events::AppUninstalled)
    end

    private def self.parse(body : String) : Slack::VerifiedEvent
      Slack::VerifiedEvent.from_json(body)
    rescue JSON::ParseException | JSON::SerializableError
      raise RequestAuthorizationError.new(:invalid_payload)
    end

    private def validate_event(envelope : Slack::VerifiedEvent, app_id : String) : Slack::Event
      invalid(:invalid_payload) if envelope.type != "event_callback" || envelope.event_id.empty?
      invalid(:app_mismatch) if envelope.api_app_id != app_id || app_id.empty?
      event = envelope.event
      case event
      when Slack::Events::TokensRevoked
        invalid(:empty_id) if event.tokens.oauth.any?(&.empty?) || event.tokens.bot.any?(&.empty?)
        event
      when Slack::Events::AppUninstalled
        event
      else
        invalid(:unsupported_lifecycle_event)
      end
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

    private def invalid(reason : Symbol) : NoReturn
      raise RequestAuthorizationError.new(reason)
    end
  end
end

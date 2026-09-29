require "../../slack"
require "http"
require "json"
require "uri"
require "../decoder"
require "../events/verified_event"
require "../interaction"
require "../interactions/**"
require "../webhooks/verifier"
require "./query_extractor"
require "./request_context"
require "./rotation_service"

module Slack::Auth
  # Verifies signed HTTP bytes with *verifier* before decoding ownership or touching the store.
  # It decodes the verified bytes with *decoder*; see `Slack::Decoder`.
  class RequestAuthorizer
    getter extractor : QueryExtractor

    @configuration : APIConfiguration

    def initialize(expected_app_id : String, @store : InstallationStore,
                   @transport : Transport, configuration : APIConfiguration,
                   @verifier : Slack::Webhooks::Verifier, *, @rotation : RotationService? = nil,
                   @decoder : Slack::Decoder = Slack::Decoder.default)
      if rotation = @rotation
        unless rotation.store.same?(@store)
          raise ContractError.new(:invalid_configuration)
        end
      end
      @extractor = QueryExtractor.new(expected_app_id)
      @configuration = APIConfiguration.new(URI.parse(configuration.base_uri.to_s))
      ScopedTransport.validate_configuration(@configuration.base_uri)
    end

    def authorize_event(request : HTTP::Request, grant : GrantKey,
                        selected_owner : InstallationKey? = nil) : RequestContext
      payload = parse_event(verify(request))
      authorize_trusted(payload, grant, selected_owner)
    end

    def authorize_command(request : HTTP::Request, grant : GrantKey) : RequestContext
      payload = parse_command(verify(request))
      authorize_trusted(payload, grant)
    end

    def authorize_interaction(request : HTTP::Request, grant : GrantKey) : RequestContext
      payload = parse_interaction(verify(request))
      authorize_trusted(payload, grant)
    end

    # This entry point is only for payloads already verified by trusted application routing.
    def authorize_trusted(event : Slack::VerifiedEvent, grant : GrantKey,
                          selected_owner : InstallationKey? = nil) : RequestContext
      context(@extractor.extract(event, grant, selected_owner))
    end

    # This entry point is only for payloads already verified by trusted application routing.
    def authorize_trusted(command : Slack::Command, grant : GrantKey) : RequestContext
      context(@extractor.extract(command, grant))
    end

    # This entry point is only for payloads already verified by trusted application routing.
    def authorize_trusted(interaction : Slack::Interaction, grant : GrantKey) : RequestContext
      context(@extractor.extract(interaction, grant))
    end

    private def verify(request : HTTP::Request) : String
      @verifier.verify(request).body
    end

    # A `url_verification` or `app_rate_limited` body carries no event to authorize.
    private def parse_event(body : String) : Slack::VerifiedEvent
      envelope = @decoder.event(body)
      envelope.is_a?(Slack::VerifiedEvent) ? envelope : invalid_payload
    rescue JSON::ParseException | JSON::SerializableError
      invalid_payload
    end

    private def parse_command(body : String) : Slack::Command
      @decoder.command(body)
    rescue JSON::ParseException | JSON::SerializableError
      invalid_payload
    end

    private def parse_interaction(body : String) : Slack::Interaction
      @decoder.interaction(body)
    rescue JSON::ParseException | JSON::SerializableError
      invalid_payload
    end

    private def context(query : InstallationQuery) : RequestContext
      reference = if rotation = @rotation
                    rotation.rotate(query)
                  else
                    @store.acquire(query)
                  end
      RequestContext.new(query, reference, @store, @transport, @configuration)
    end

    private def invalid_payload : NoReturn
      raise RequestAuthorizationError.new(:invalid_payload)
    end
  end
end

require "../../slack"
require "http"
require "json"
require "uri"
require "../commands/parser"
require "../events/verified_event"
require "../interaction"
require "../interactions/**"
require "../webhooks/verified_request"
require "./query_extractor"
require "./request_context"

module Slack::Auth
  # Verifies signed HTTP bytes before decoding ownership or touching the store.
  class RequestAuthorizer
    getter extractor : QueryExtractor

    @configuration : APIConfiguration

    def initialize(expected_app_id : String, @store : InstallationStore,
                   @transport : Transport, configuration : APIConfiguration,
                   @clock : Proc(Time) = -> { Time.utc })
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
      Slack::Webhooks::VerifiedRequest.new(request, @clock).verify!.body
    end

    private def parse_event(body : String) : Slack::VerifiedEvent
      Slack::VerifiedEvent.from_json(body)
    rescue JSON::ParseException | JSON::SerializableError
      invalid_payload
    end

    private def parse_command(body : String) : Slack::Command
      Slack::Commands::Parser.parse(body)
    rescue JSON::ParseException | JSON::SerializableError
      invalid_payload
    end

    private def parse_interaction(body : String) : Slack::Interaction
      values = [] of String
      URI::Params.parse(body).each { |key, value| values << value if key == "payload" }
      invalid_payload unless values.size == 1
      Slack::Interaction.from_json(values.first)
    rescue JSON::ParseException | JSON::SerializableError
      invalid_payload
    end

    private def context(query : InstallationQuery) : RequestContext
      reference = @store.acquire(query)
      RequestContext.new(query, reference, @store, @transport, @configuration)
    end

    private def invalid_payload : NoReturn
      raise RequestAuthorizationError.new(:invalid_payload)
    end
  end
end

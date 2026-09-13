require "base64"
require "./endpoint_validator"
require "../oauth/refresh_response"

module Slack::Auth
  # One refresh grant exchange. Call through RotationService for stored grants.
  class RefreshClient
    @token_uri : String
    @authorization : Secret

    def initialize(configuration : OAuthConfiguration, @transport : Transport)
      EndpointValidator.validate!(configuration.token_uri, query_allowed: false)
      if configuration.token_uri.scheme != "https" || configuration.client_id.blank? ||
         configuration.client_id.includes?(':') || configuration.client_secret.value.blank?
        raise ContractError.new(:invalid_configuration)
      end
      @token_uri = configuration.token_uri.to_s
      @authorization = Secret.new("Basic " + Base64.strict_encode(
        "#{configuration.client_id}:#{configuration.client_secret.value}"))
    end

    def refresh(refresh_token : Secret) : Slack::RefreshResponse
      response = @transport.execute(TransportRequest.new(
        "POST", URI.parse(@token_uri),
        HTTP::Headers{
          "Content-Type"  => "application/x-www-form-urlencoded",
          "Authorization" => @authorization.value,
        },
        URI::Params.encode({"grant_type" => "refresh_token", "refresh_token" => refresh_token.value})
      ))
      Slack::RefreshResponse.parse(response)
    rescue error : ContractError | ResponseError
      raise error
    rescue
      # An unclassified transport exception cannot establish that nothing was sent.
      raise ContractError.new(:unknown_remote_outcome)
    end

    def inspect(io : IO) : Nil
      io << "Slack::Auth::RefreshClient([REDACTED])"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end
  end
end

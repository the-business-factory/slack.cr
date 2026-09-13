require "base64"
require "uri"
require "./endpoint_validator"

module Slack::Auth
  class ProxyConfiguration
    getter host : String
    getter port : Int32
    getter authorization : String?

    def initialize(uri : URI)
      @host = uri.host || invalid!
      EndpointValidator.validate_host!(@host)
      invalid! unless uri.scheme.try(&.downcase) == "http"
      invalid! unless uri.fragment.nil? && uri.query.nil?
      invalid! unless uri.path.empty? || uri.path == "/"

      raw_port = uri.port || 80
      invalid! unless (1..65_535).includes?(raw_port)
      @port = raw_port
      @authorization = authorization(uri)
    end

    private def authorization(uri : URI) : String?
      user = uri.user
      password = uri.password
      invalid! if user.nil? != password.nil?
      return unless user && password
      invalid! if user.empty?

      "Basic #{Base64.strict_encode("#{user}:#{password}")}"
    end

    private def invalid! : NoReturn
      raise ContractError.new(ErrorCode::InvalidConfiguration)
    end
  end
end

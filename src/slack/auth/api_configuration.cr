require "uri"
require "./endpoint_validator"

module Slack::Auth
  class APIConfiguration
    @base_uri : URI

    def self.default : self
      new(URI.parse("https://slack.com/api/"))
    end

    def initialize(base_uri : URI)
      EndpointValidator.validate!(base_uri, query_allowed: false)
      @base_uri = normalized(base_uri)
    end

    def base_uri : URI
      @base_uri.dup
    end

    def endpoint(method_path : String, query : String? = nil) : URI
      invalid! unless method_path.matches?(/\A[A-Za-z0-9._-]+\z/)

      result = @base_uri.dup
      result.path = "#{@base_uri.path}#{method_path}"
      result.query = query
      result
    end

    private def normalized(uri : URI) : URI
      result = uri.dup
      path = result.path
      path = "/" if path.empty?
      result.path = path.ends_with?('/') ? path : "#{path}/"
      result
    end

    private def invalid! : NoReturn
      raise ContractError.new(ErrorCode::InvalidConfiguration)
    end
  end
end

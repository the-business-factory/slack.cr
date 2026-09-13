# https://api.slack.com/web
#
# Pass arguments as:
#
# GET querystring parameters
# POST parameters presented as application/x-www-form-urlencoded
# or a mix of both GET and POST parameters
#
# Most write methods allow arguments application/json attributes.
# https://api.slack.com/web#methods_supporting_json
abstract struct Slack::Api::Base
  include JSON::Serializable
  include Slack::InitializerMacros

  @[JSON::Field(ignore: true)]
  @result : HTTP::Client::Response?

  @[JSON::Field(ignore: true)]
  required_properties_with_initializer token : String?

  @[JSON::Field(ignore: true)]
  named_properties_with_initializer configuration : Slack::Auth::APIConfiguration = Slack.settings.api_configuration

  @[JSON::Field(ignore: true)]
  named_properties_with_initializer limiter : RateLimiter::LimiterLike? = nil

  @[JSON::Field(ignore: true)]
  named_properties_with_initializer transport : Slack::Auth::Transport? = nil

  def self.tokenless(*, transport : Slack::Auth::Transport, limiter : RateLimiter::LimiterLike,
                     **arguments) : self
    new(**arguments, token: nil, transport: transport, limiter: limiter)
  end

  abstract def call : Slack::Model
  abstract def content_type : ContentTypes
  abstract def method_path : String
  abstract def result : HTTP::Client::Response

  def request_url : String
    configuration.endpoint(method_path, query).to_s
  end

  def query : String?
    nil
  end

  def headers : HTTP::Headers
    headers = HTTP::Headers{"Content-Type" => content_type.to_s}
    headers["Authorization"] = "Bearer #{token}" if token
    headers
  end

  def api_client : Slack::ApiClient
    ApiClient.new(api: self, limiter: limiter, transport: transport)
  end
end

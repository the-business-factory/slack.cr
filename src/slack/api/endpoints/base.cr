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
  properties_with_initializer token : String

  abstract def call : Slack::Model
  abstract def content_type : ContentTypes
  abstract def request_url : String
  abstract def result : HTTP::Client::Response

  def headers
    HTTP::Headers{
      "Content-Type"  => content_type.to_s,
      "Authorization" => "Bearer #{token}",
    }
  end
end

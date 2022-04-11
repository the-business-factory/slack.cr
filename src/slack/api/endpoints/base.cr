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
abstract class Slack::Api::Base
  include JSON::Serializable
  include Slack::InitializerMacros

  getter token

  abstract def base_url
  abstract def call : Slack::Model
  abstract def content_type : ContentTypes

  def headers
    HTTP::Headers{
      "Content-Type"  => content_type.to_s,
      "Authorization" => "Bearer #{token}",
    }
  end
end

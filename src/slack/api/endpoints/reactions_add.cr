# https://api.slack.com/methods/reactions.add
class Slack::Api::ReactionsAdd < Slack::Api::Base
  properties_with_initializer \
    channel : String,
    name : String,
    token : String,
    timestamp : String

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def base_url
    "https://slack.com/api/reactions.add"
  end

  def call : Slack::Models::DefaultResponse
    result = HTTP::Client.post(url: base_url, headers: headers, body: to_json)
    ResponseHandler(Slack::Models::DefaultResponse).from_json(result.body)
  end
end

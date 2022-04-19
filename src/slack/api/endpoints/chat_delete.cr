# https://api.slack.com/methods/chat.delete
class Slack::Api::ChatDelete < Slack::Api::Base
  properties_with_initializer channel : String, token : String, ts : String

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def base_url
    "https://slack.com/api/chat.delete"
  end

  def call : Slack::Models::Chat::Delete
    result = HTTP::Client.post(url: base_url, headers: headers, body: to_json)
    ResponseHandler(Models::Chat::Delete).from_json(result.body)
  end
end

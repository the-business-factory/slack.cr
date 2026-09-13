# https://api.slack.com/methods/chat.delete
struct Slack::Api::ChatDelete < Slack::Api::Base
  properties_with_initializer channel : String, ts : String

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def method_path : String
    "chat.delete"
  end

  def result : HTTP::Client::Response
    @result ||= api_client.post(body: to_json)
  end

  def call : Slack::Models::Chat::Delete
    ResponseHandler(Models::Chat::Delete).from_json(result.body)
  end
end

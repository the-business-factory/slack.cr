# https://api.slack.com/methods/chat.delete
struct Slack::Api::ChatDelete < Slack::Api::Base
  properties_with_initializer channel : String, ts : String

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def request_url : String
    "https://slack.com/api/chat.delete"
  end

  def result : HTTP::Client::Response
    @result ||= ApiClient.new(api: self).post(body: to_json)
  end

  def call : Slack::Models::Chat::Delete
    ResponseHandler(Models::Chat::Delete).from_json(result.body)
  end
end

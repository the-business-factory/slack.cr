# https://api.slack.com/methods/reactions.add
struct Slack::Api::ReactionsAdd < Slack::Api::Base
  properties_with_initializer \
    channel : String,
    name : String,
    timestamp : String

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def method_path : String
    "reactions.add"
  end

  def result : HTTP::Client::Response
    @result ||= api_client.post(body: to_json)
  end

  def call : Slack::Models::DefaultResponse
    ResponseHandler(Slack::Models::DefaultResponse).from_json(result.body)
  end
end

# https://api.slack.com/methods/reactions.add
class Slack::Api::ReactionsAdd < Slack::Api::Base
  properties_with_initializer \
    channel : String,
    name : String,
    timestamp : String

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def request_url : String
    "https://slack.com/api/reactions.add"
  end

  def result : HTTP::Client::Response
    @result ||= HTTP::Client
      .post(url: request_url, headers: headers, body: to_json)
  end

  def call : Slack::Models::DefaultResponse
    ResponseHandler(Slack::Models::DefaultResponse).from_json(result.body)
  end
end

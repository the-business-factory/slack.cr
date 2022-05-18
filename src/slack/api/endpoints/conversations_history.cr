# https://api.slack.com/methods/conversations.history
class Slack::Api::ConversationsHistory < Slack::Api::Base
  properties_with_initializer \
    channel : String,
    cursor : String?,
    include_all_metadata : Bool = false,
    inclusive : Bool = false,
    latest : String?,
    oldest : String?

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def request_url : String
    "https://slack.com/api/conversations.history?#{url_params}"
  end

  def url_params
    HTTP::Params.build do |form|
      form.add "channel", channel
      form.add "cursor", cursor if cursor
      form.add "include_all_metadata", include_all_metadata.to_s
      form.add "inclusive", inclusive.to_s
      form.add "latest", latest if latest
      form.add "oldest", oldest if oldest
    end
  end

  def result : HTTP::Client::Response
    @result ||= ApiClient.new(api: self).get(body: to_json)
  end

  def call : Slack::Models::ConversationsHistory
    ResponseHandler(Models::ConversationsHistory).from_json(result.body)
  end
end

# https://api.slack.com/methods/conversations.history
struct Slack::Api::ConversationsHistory < Slack::Api::Base
  properties_with_initializer \
    channel : String,
    cursor : String? = nil,
    include_all_metadata : Bool = false,
    inclusive : Bool = false,
    latest : String? = nil,
    oldest : String? = nil

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def method_path : String
    "conversations.history"
  end

  def query : String
    HTTP::Params.build do |form|
      form.add "channel", channel
      form.add "cursor", cursor if cursor
      form.add "include_all_metadata", include_all_metadata.to_s
      form.add "inclusive", inclusive.to_s
      form.add "latest", latest if latest
      form.add "oldest", oldest if oldest
    end
  end

  def url_params : String
    query
  end

  def result : HTTP::Client::Response
    @result ||= api_client.get(body: to_json)
  end

  def call : Slack::Models::ConversationsHistory
    ResponseHandler(Models::ConversationsHistory).from_json(result.body)
  end
end

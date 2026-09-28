# :nodoc:
# Internal bridge to ApiClient. CheckedChatUpdate owns the wire body.
private struct Slack::Api::ChatUpdateDescriptor < Slack::Api::Base
  @[JSON::Field(ignore: true)]
  properties_with_initializer body : String

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def method_path : String
    "chat.update"
  end

  def result : HTTP::Client::Response
    @result ||= api_client.post(body: body)
  end

  def call : Slack::Models::Chat::UpdateMessage
    ResponseHandler(Slack::Models::Chat::UpdateMessage).from_json(result.body)
  end
end

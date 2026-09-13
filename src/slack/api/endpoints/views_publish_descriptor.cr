# Internal bridge to ApiClient. Only CheckedViewsPublish assembles the wire body.
private struct Slack::Api::ViewsPublishDescriptor < Slack::Api::Base
  @[JSON::Field(ignore: true)]
  properties_with_initializer body : String

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def method_path : String
    "views.publish"
  end

  def result : HTTP::Client::Response
    @result ||= api_client.post(body: body)
  end

  def call : Slack::Models::ViewsPublish
    ResponseHandler(Slack::Models::ViewsPublish).from_json(result.body)
  end
end

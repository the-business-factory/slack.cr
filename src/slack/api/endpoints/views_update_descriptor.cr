# :nodoc:
# Internal bridge to ApiClient. Only CheckedViewsUpdate assembles the wire body.
private struct Slack::Api::ViewsUpdateDescriptor < Slack::Api::Base
  @[JSON::Field(ignore: true)]
  properties_with_initializer body : String

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def method_path : String
    "views.update"
  end

  def result : HTTP::Client::Response
    @result ||= api_client.post(body: body)
  end

  def call : Slack::Models::ViewsUpdate
    ResponseHandler(Slack::Models::ViewsUpdate).from_json(result.body)
  end
end

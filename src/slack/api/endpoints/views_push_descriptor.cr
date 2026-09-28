# :nodoc:
# Internal bridge to ApiClient. Only CheckedViewsPush assembles the wire body.
private struct Slack::Api::ViewsPushDescriptor < Slack::Api::Base
  @[JSON::Field(ignore: true)]
  properties_with_initializer body : String

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def method_path : String
    "views.push"
  end

  def result : HTTP::Client::Response
    @result ||= api_client.post(body: body)
  end

  def call : Slack::Models::ViewsPush
    ResponseHandler(Slack::Models::ViewsPush).from_json(result.body)
  end
end

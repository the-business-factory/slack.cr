# :nodoc:
# Internal bridge from validated requests to ApiClient. The request owns
# the wire body. `T` is the response model, so each Slack method keeps its own
# default limiter: ApiClient keys limiters by token and request class.
private struct Slack::Api::JsonBodyRequest(T) < Slack::Api::Base
  @[JSON::Field(ignore: true)]
  properties_with_initializer method_path : String, body : String

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def result : HTTP::Client::Response
    @result ||= api_client.post(body: body)
  end

  def call : Slack::Model
    ResponseHandler(T).from_json(result.body)
  end
end

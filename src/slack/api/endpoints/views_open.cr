struct Slack::Api::ViewsOpen < Slack::Api::Base
  properties_with_initializer trigger_id : String, view : Slack::UI::Modal

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def method_path : String
    "views.open"
  end

  def result : HTTP::Client::Response
    return result if result = @result

    # Serializing rechecks relationships that legacy Modal mutation can change.
    body = to_json
    @result = api_client.post(body: body)
  end

  def call : Slack::Models::ViewsOpen
    ResponseHandler(Models::ViewsOpen).from_json(result.body)
  end
end

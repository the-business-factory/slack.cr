struct Slack::Api::ViewsOpen < Slack::Api::Base
  properties_with_initializer trigger_id : String, view : Slack::UI::Modal

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def method_path : String
    "views.open"
  end

  def result : HTTP::Client::Response
    @result ||= api_client.post(body: to_json)
  end

  def call : Slack::Models::ViewsOpen
    ResponseHandler(Models::ViewsOpen).from_json(result.body)
  end
end

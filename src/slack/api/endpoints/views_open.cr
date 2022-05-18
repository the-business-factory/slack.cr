class Slack::Api::ViewsOpen < Slack::Api::Base
  properties_with_initializer trigger_id : String, view : Slack::UI::Modal

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def request_url : String
    "https://slack.com/api/views.open"
  end

  def result : HTTP::Client::Response
    @result ||= ApiClient.new(api: self).post(body: to_json)
  end

  def call : Slack::Models::ViewsOpen
    ResponseHandler(Models::ViewsOpen).from_json(result.body)
  end
end

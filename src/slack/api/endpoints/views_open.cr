class Slack::Api::ViewsOpen < Slack::Api::Base
  property token : String, trigger_id : String, view : Slack::UI::Modal

  def initialize(@token : String,
                 @trigger_id : String,
                 @view : Slack::UI::Modal)
  end

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def base_url
    "https://slack.com/api/views.open"
  end

  def call : Slack::Models::ViewsOpen
    json_body = {view: view, trigger_id: trigger_id}.to_json
    result = HTTP::Client.post(url: base_url, headers: headers, body: json_body)
    ResponseHandler(Models::ViewsOpen).from_json(result.body)
  end
end

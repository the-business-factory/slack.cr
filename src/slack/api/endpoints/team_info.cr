struct Slack::Api::TeamInfo < Slack::Api::Base
  def content_type : ContentTypes
    ContentTypes::FormEncoded
  end

  def method_path : String
    "team.info"
  end

  def result : HTTP::Client::Response
    @result ||= api_client.get
  end

  def call : Slack::Models::Team
    ResponseHandler(Models::Team).from_json(result.body) do |json|
      Models::Team.from_json(json)
    end
  end
end

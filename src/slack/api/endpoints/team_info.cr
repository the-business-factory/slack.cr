class Slack::Api::TeamInfo < Slack::Api::Base
  def content_type : ContentTypes
    ContentTypes::FormEncoded
  end

  def request_url : String
    "https://slack.com/api/team.info"
  end

  def result : HTTP::Client::Response
    @result ||= ApiClient.new(api: self).get
  end

  def call : Slack::Models::Team
    ResponseHandler(Models::Team).from_json(result.body) do |json|
      Models::Team.from_json(json)
    end
  end
end

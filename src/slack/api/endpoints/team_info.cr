class Slack::Api::TeamInfo < Slack::Api::Base
  def initialize(@token : String)
  end

  def content_type : ContentTypes
    ContentTypes::FormEncoded
  end

  def base_url
    "https://slack.com/api/team.info"
  end

  def call : Slack::Models::Team
    result = HTTP::Client.get(base_url, headers: headers)
    Slack::Models::Team.from_json(result.body)
  end
end

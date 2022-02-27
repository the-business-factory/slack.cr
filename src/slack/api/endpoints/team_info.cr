class Slack::Api::TeamInfo < Slack::Api::Base
  def content_type : ContentTypes
    ContentTypes::FormEncoded
  end

  def base_url
    "https://slack.com/api/team.info"
  end

  def call
    result = HTTP::Client.get(base_url, headers: headers)
    Slack::Api::Team.from_json(result.body)
  end
end

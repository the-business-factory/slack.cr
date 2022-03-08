class Slack::Api::ConversationsInfo < Slack::Api::Base
  getter channel

  def initialize(@token : String, @channel : String)
  end

  def content_type : ContentTypes
    ContentTypes::FormEncoded
  end

  def base_url
    "https://slack.com/api/conversations.info?channel=#{channel}"
  end

  def call : Slack::Models::ConversationType
    result = HTTP::Client.get(base_url, headers: headers)
    Slack::Models::Conversation.from_json(result.body)
  end
end

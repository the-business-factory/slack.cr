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

  def call : Models::Conversation
    result = HTTP::Client.get(base_url, headers: headers).body

    ResponseHandler(Models::Conversation).from_json(result) do |json|
      Models::ConversationFactory.from_json json
    end
  end
end

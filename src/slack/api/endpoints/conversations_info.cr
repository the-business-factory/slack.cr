struct Slack::Api::ConversationsInfo < Slack::Api::Base
  properties_with_initializer channel : String

  def content_type : ContentTypes
    ContentTypes::FormEncoded
  end

  def request_url : String
    "https://slack.com/api/conversations.info?channel=#{channel}"
  end

  def result : HTTP::Client::Response
    @result ||= ApiClient.new(api: self).get
  end

  def call : Models::Conversation
    ResponseHandler(Models::Conversation).from_json(result.body) do |json|
      Models::ConversationFactory.from_json json
    end
  end
end

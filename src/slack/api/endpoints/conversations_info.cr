struct Slack::Api::ConversationsInfo < Slack::Api::Base
  properties_with_initializer channel : String

  def content_type : ContentTypes
    ContentTypes::FormEncoded
  end

  def method_path : String
    "conversations.info"
  end

  def query : String
    HTTP::Params.encode({"channel" => channel})
  end

  def result : HTTP::Client::Response
    @result ||= api_client.get
  end

  def call : Models::Conversation
    ResponseHandler(Models::Conversation).from_json(result.body) do |json|
      Models::ConversationFactory.from_json json
    end
  end
end

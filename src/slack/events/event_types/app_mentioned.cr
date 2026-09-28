struct Slack::Events::AppMentioned < Slack::Event
  # The canvas section that mentions the app, in a `document_mention` subtype.
  # https://docs.slack.dev/reference/events/message/document_mention
  struct DocumentMention
    include JSON::Serializable

    getter file_id : String
    getter section_id : String
    getter mentioning_user_ids : Array(String) = [] of String
  end

  property channel : String, user : String

  # `document_mention` when the app is mentioned in the body of a canvas; nil
  # for a mention in a message.
  getter subtype : String?

  getter document_mention : DocumentMention?
end

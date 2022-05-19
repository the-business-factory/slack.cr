struct Slack::Api::ChatPostMessage < Slack::Api::Base
  properties_with_initializer \
    channel : String,
    text : String?,
    blocks : Array(Slack::UI::Block)?,
    attachments : Array(EventData::Attachment)?

  def self.post_blocks(blocks : Enumerable,
                       channel : String,
                       token : String,
                       thread_ts : String? = nil)
    new(
      token: token,
      channel: channel,
      blocks: blocks.map &.as(Slack::UI::Block),
      thread_ts: thread_ts
    ).call
  end

  properties_with_initializer \
    icon_emoji : String?,
    icon_url : String?,
    link_names : Bool?,
    mrkdwn : Bool?,
    parse : String? = "none",
    reply_broadcast : Bool?,
    thread_ts : String?,
    unfurl_links : Bool?,
    unfurl_media : Bool?,
    username : String?

  def after_initialize
    return if text || blocks || attachments

    raise "'text', 'blocks', or 'attachments' are required for a message."
  end

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def request_url : String
    "https://slack.com/api/chat.postMessage"
  end

  def result : HTTP::Client::Response
    @result ||= ApiClient.new(api: self).post(body: to_json)
  end

  def call : Slack::Models::Chat::PostMessage
    ResponseHandler(Models::Chat::PostMessage).from_json(result.body)
  end
end

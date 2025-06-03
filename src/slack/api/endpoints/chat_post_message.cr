struct Slack::Api::ChatPostMessage < Slack::Api::Base
  properties_with_initializer \
    channel : String,
    text : String? = nil,
    blocks : Array(Slack::UI::Block)? = nil,
    attachments : Array(EventData::Attachment)? = nil

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
    icon_emoji : String? = nil,
    icon_url : String? = nil,
    link_names : Bool? = nil,
    mrkdwn : Bool? = nil,
    parse : String? = "none",
    reply_broadcast : Bool? = nil,
    thread_ts : String? = nil,
    unfurl_links : Bool? = nil,
    unfurl_media : Bool? = nil,
    username : String? = nil

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

class Slack::Api::ChatPostMessage < Slack::Api::Base
  properties_with_initializer \
    token : String,
    channel : String,
    text : String?,
    blocks : Array(Slack::UI::Block)?,
    attachments : Array(EventData::Attachment)?

  # Add a helper so Array(Slack::UI::Block) can be easily passed for calls that
  # allow mixed blocks. (chat.postMessage, etc). This is a bit of a hack to get
  # around the fact that the Array could be many different types depending on
  # the user, as the user is creating the Array type -- e.g:
  #
  # Array(Slack::UI::Blocks::Section | Slack::UI::Blocks::Input)?
  #
  # This should be improved with something that handles type guards a bit more
  # elegantly or something that propertly handles the combinatorics on arrays.
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

  # Extract this into a configuration object.
  #
  # Options -- https://api.slack.com/methods/chat.postMessage
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

  def base_url
    "https://slack.com/api/chat.postMessage"
  end

  def call : Slack::Models::Chat::PostMessage
    result = HTTP::Client.post(url: base_url, headers: headers, body: to_json)
    ResponseHandler(Models::Chat::PostMessage).from_json(result.body)
  end
end

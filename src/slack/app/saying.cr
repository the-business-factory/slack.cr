# :nodoc:
# `say` for contexts whose payload can name a channel. Each context gives the
# channel through `#say_channel`.
module Slack::App::Saying
  # Posts *text* with `chat.postMessage` to the channel of the payload through
  # `client`, and returns Slack's result. The reply goes into a thread only
  # when you give *thread_ts*.
  #
  # Raises `NoReplyTarget` when the payload has no channel, `UI::ValidationError`
  # for an invalid message, and the errors of `Api::Client#call`.
  def say(text : String, *, thread_ts : String? = nil,
          attachments : Enumerable(Slack::UI::Attachment)? = nil,
          metadata : Slack::UI::MessageMetadata? = nil) : Slack::Models::Chat::PostMessage
    client.call(Slack::Api::ChatPostMessage.new(channel: reply_channel, text: text,
      attachments: attachments, thread_ts: thread_ts, metadata: metadata))
  end

  # Posts the Block Kit *message*. See the text overload.
  def say(message : Slack::UI::Message, *, thread_ts : String? = nil,
          attachments : Enumerable(Slack::UI::Attachment)? = nil,
          metadata : Slack::UI::MessageMetadata? = nil) : Slack::Models::Chat::PostMessage
    client.call(Slack::Api::ChatPostMessage.new(channel: reply_channel, message: message,
      attachments: attachments, thread_ts: thread_ts, metadata: metadata))
  end

  private abstract def say_channel : String?

  private def reply_channel : String
    say_channel || raise NoReplyTarget.new("The payload has no channel for say")
  end
end

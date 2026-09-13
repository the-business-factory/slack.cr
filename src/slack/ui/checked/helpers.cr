module Slack::UI::Checked
  def self.plain(text : String, emoji : Bool? = nil) : CompositionObjects::PlainText
    CompositionObjects::PlainText.new(text: text, emoji: emoji)
  end

  def self.mrkdwn(text : String, verbatim : Bool? = nil) : CompositionObjects::Mrkdwn
    CompositionObjects::Mrkdwn.new(text: text, verbatim: verbatim)
  end

  def self.message(fallback_text : String, & : MessageBuilder ->) : Message
    builder = MessageBuilder.new(fallback_text: fallback_text)
    yield builder
    builder.build
  end

  def self.message_with_slack_generated_fallback(& : MessageBuilder ->) : Message
    builder = MessageBuilder.with_slack_generated_fallback
    yield builder
    builder.build
  end
end

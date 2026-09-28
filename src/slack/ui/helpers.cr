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

module Slack::UI::Checked
  def self.display_modal(
    title : CompositionObjects::PlainText,
    submit : CompositionObjects::PlainText? = nil,
    close : CompositionObjects::PlainText? = nil,
    private_metadata : String? = nil,
    callback_id : String? = nil,
    external_id : String? = nil,
    clear_on_close : Bool? = nil,
    notify_on_close : Bool? = nil,
    submit_disabled : Bool? = nil,
    & : DisplayModalBuilder ->
  ) : DisplayModal
    builder = DisplayModalBuilder.new(
      title: title,
      submit: submit,
      close: close,
      private_metadata: private_metadata,
      callback_id: callback_id,
      external_id: external_id,
      clear_on_close: clear_on_close,
      notify_on_close: notify_on_close,
      submit_disabled: submit_disabled
    )
    yield builder
    builder.build
  end
end

module Slack::UI::Checked
  def self.form_modal(
    title : CompositionObjects::PlainText,
    submit : CompositionObjects::PlainText,
    close : CompositionObjects::PlainText? = nil,
    private_metadata : String? = nil,
    callback_id : String? = nil,
    external_id : String? = nil,
    clear_on_close : Bool? = nil,
    notify_on_close : Bool? = nil,
    submit_disabled : Bool? = nil,
    & : FormModalBuilder ->
  ) : FormModal
    builder = FormModalBuilder.new(
      title: title,
      submit: submit,
      close: close,
      private_metadata: private_metadata,
      callback_id: callback_id,
      external_id: external_id,
      clear_on_close: clear_on_close,
      notify_on_close: notify_on_close,
      submit_disabled: submit_disabled
    )
    yield builder
    builder.build
  end
end

module Slack::UI::Checked
  def self.home(
    private_metadata : String? = nil,
    callback_id : String? = nil,
    external_id : String? = nil,
    & : HomeBuilder ->
  ) : Home
    builder = HomeBuilder.new(private_metadata: private_metadata, callback_id: callback_id, external_id: external_id)
    yield builder
    builder.build
  end
end

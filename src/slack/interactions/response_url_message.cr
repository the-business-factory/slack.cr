# JSON body that `ResponseUrlResponder#post` sends to a `response_url`.
#
# A message without `response_type` is ephemeral. To reply in a thread, use
# `ResponseType::InChannel` with `thread_ts`; `replace_original` is then sent
# as `false`, so the reply does not overwrite the source message. To change or remove the message
# that holds the used component, use `replace_original: true` or
# `.delete_original`.
#
# ```
# Slack::Interactions::ResponseUrlMessage.new(text: "Approved.", replace_original: true)
# # => {"replace_original":true,"text":"Approved."}
# ```
#
# https://docs.slack.dev/interactivity/handling-user-interaction
struct Slack::Interactions::ResponseUrlMessage
  include Slack::UI::ValueValidation

  getter response_type : ResponseType?
  getter text : String?
  getter message : Slack::UI::Message?
  getter replace_original : Bool?
  getter thread_ts : String?
  getter? delete_original : Bool = false

  def initialize(*, text : String, @response_type : ResponseType? = nil,
                 @replace_original : Bool? = nil, @thread_ts : String? = nil)
    @text = text
    @message = nil
    keep_source_in_thread
    validate!
  end

  def initialize(*, message : Slack::UI::Message, @response_type : ResponseType? = nil,
                 @replace_original : Bool? = nil, @thread_ts : String? = nil)
    @text = nil
    @message = message
    keep_source_in_thread
    validate!
  end

  # Slack requires `delete_original` as the sole attribute.
  def self.delete_original : ResponseUrlMessage
    new(delete_original: true)
  end

  private def initialize(*, @delete_original : Bool)
  end

  # Slack documents `in_channel` and `replace_original: false` as required for
  # a thread reply. Nonblank text is library policy.
  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if (text = @text) && text.blank?
      issues << Slack::UI::ValidationIssue.new("response_url_message.text.blank", "text", "Text must not be blank.")
    end
    if @thread_ts && !@response_type.try(&.in_channel?)
      issues << Slack::UI::ValidationIssue.new("response_url_message.thread_ts.requires_in_channel", "thread_ts",
        "A thread reply must use response_type in_channel.")
    end
    if @thread_ts && @replace_original
      issues << Slack::UI::ValidationIssue.new("response_url_message.thread_ts.replace_original", "replace_original",
        "A thread reply must not replace the source message.")
    end
    @message.try { |message| issues.concat(message.validate) }
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      if delete_original?
        json.field "delete_original", true
      else
        content_to_json(json)
      end
    end
  end

  # Without `replace_original: false`, Slack overwrites the source message
  # instead of replying in its thread.
  private def keep_source_in_thread : Nil
    @replace_original = false if @thread_ts && @replace_original.nil?
  end

  private def content_to_json(json : JSON::Builder) : Nil
    json.field "response_type", @response_type if @response_type
    json.field "replace_original", @replace_original unless @replace_original.nil?
    json.field "thread_ts", @thread_ts if @thread_ts
    json.field "text", @text if @text
    if message = @message
      json.field "text", message.fallback_text if message.fallback_text
      json.field("blocks") { message.blocks_to_json(json) }
    end
  end
end

# The surface where a block action happened. Types this library does not model
# decode as `Container::Unknown` and keep their raw JSON.
# https://docs.slack.dev/reference/interaction-payloads/block_actions-payload/
abstract struct Slack::Interactions::Container
  # Returns nil for an absent or null container. Raises `TypeMismatch` when the
  # container is not an object or a known type has a malformed field.
  def self.decode(raw : JSON::Any?, path : String = "container") : Container?
    return if raw.nil?
    object = PayloadAccess.object?(raw, path)
    return unless object
    type = PayloadAccess.string?(object["type"]?, "#{path}.type")
    case type
    when "message"            then Message.new(object, path)
    when "view"               then View.new(object, path)
    when "message_attachment" then MessageAttachment.new(object, path)
    else                           Unknown.new(type, raw)
    end
  end

  # A block in a message.
  struct Message < Container
    getter message_ts : String
    getter channel_id : String
    getter is_ephemeral : Bool?

    def initialize(object : Hash(String, JSON::Any), path : String)
      @message_ts = PayloadAccess.string(object["message_ts"]?, "#{path}.message_ts")
      @channel_id = PayloadAccess.string(object["channel_id"]?, "#{path}.channel_id")
      @is_ephemeral = PayloadAccess.bool?(object["is_ephemeral"]?, "#{path}.is_ephemeral")
    end
  end

  # A block in a modal or Home view.
  struct View < Container
    getter view_id : String

    def initialize(object : Hash(String, JSON::Any), path : String)
      @view_id = PayloadAccess.string(object["view_id"]?, "#{path}.view_id")
    end
  end

  # A block in a message attachment, such as an app unfurl.
  struct MessageAttachment < Container
    getter message_ts : String
    getter attachment_id : Int64
    getter channel_id : String
    getter is_ephemeral : Bool?
    getter is_app_unfurl : Bool?

    def initialize(object : Hash(String, JSON::Any), path : String)
      @message_ts = PayloadAccess.string(object["message_ts"]?, "#{path}.message_ts")
      @attachment_id = PayloadAccess.int64(object["attachment_id"]?, "#{path}.attachment_id")
      @channel_id = PayloadAccess.string(object["channel_id"]?, "#{path}.channel_id")
      @is_ephemeral = PayloadAccess.bool?(object["is_ephemeral"]?, "#{path}.is_ephemeral")
      @is_app_unfurl = PayloadAccess.bool?(object["is_app_unfurl"]?, "#{path}.is_app_unfurl")
    end
  end

  # A container type this library does not model. `type` is nil when absent or null.
  struct Unknown < Container
    getter type : String?
    getter raw : JSON::Any

    def initialize(@type : String?, @raw : JSON::Any)
    end
  end
end

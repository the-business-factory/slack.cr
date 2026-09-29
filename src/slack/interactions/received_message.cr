# The source message of a block action or message shortcut. It retains the
# complete payload. Typed getters read the payload when called. They return nil
# for an absent or null field and raise `TypeMismatch` for a malformed one.
struct Slack::Interactions::ReceivedMessage
  # The complete parsed message payload.
  getter payload : JSON::Any

  def self.new(pull : JSON::PullParser) : self
    new(JSON::Any.new(pull))
  end

  def initialize(@payload : JSON::Any)
  end

  def to_json(json : JSON::Builder) : Nil
    @payload.to_json(json)
  end

  def ts : String?
    string?("ts")
  end

  def thread_ts : String?
    string?("thread_ts")
  end

  def text : String?
    string?("text")
  end

  def user : String?
    string?("user")
  end

  @decoded_blocks : Array(ReceivedBlock)? = nil

  # Decodes the message blocks. Returns an empty array when the message has none.
  # The first call decodes and keeps the result. A copy of this struct made
  # before the first call decodes again.
  def blocks : Array(ReceivedBlock)
    @decoded_blocks ||= ReceivedBlocks.decode(object["blocks"]?, "message.blocks")
  end

  private def string?(key : String) : String?
    PayloadAccess.string?(object[key]?, "message.#{key}")
  end

  private def object : Hash(String, JSON::Any)
    PayloadAccess.object?(@payload, "message") || raise TypeMismatch.new("message", "object", "null")
  end
end

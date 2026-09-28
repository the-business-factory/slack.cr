# :nodoc:
# Raw JSON that can carry secrets, such as `interactivity.interactor.secret`.
# `inspect` and `to_s` redact it; `value` and `to_json` keep the complete JSON.
struct Slack::Interactions::RedactedJSON
  getter value : JSON::Any

  def self.new(pull : JSON::PullParser) : self
    new(JSON::Any.new(pull))
  end

  def initialize(@value : JSON::Any)
  end

  def inspect(io : IO) : Nil
    io << "[REDACTED]"
  end

  def to_s(io : IO) : Nil
    inspect(io)
  end

  def to_json(json : JSON::Builder) : Nil
    @value.to_json(json)
  end
end

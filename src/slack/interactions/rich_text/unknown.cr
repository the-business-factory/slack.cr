# Retains a rich text node type that this library does not read.
struct Slack::Interactions::RichText::Unknown
  getter type : String
  getter raw : JSON::Any

  def initialize(@type : String, @raw : JSON::Any)
  end
end

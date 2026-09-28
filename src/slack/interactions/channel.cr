# The conversation where an interaction happened.
struct Slack::Interactions::Channel
  include JSON::Serializable

  getter id : String
  getter name : String?

  def initialize(@id : String, @name : String? = nil)
  end
end

require "json"

struct Slack::Auth::Enterprise
  include JSON::Serializable

  property id : String, name : String?

  def initialize(@id : String, @name : String? = nil)
  end
end

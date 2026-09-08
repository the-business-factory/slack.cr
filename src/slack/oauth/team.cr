require "json"

struct Slack::Auth::Team
  include JSON::Serializable

  property id : String, name : String?

  def initialize(@id : String, @name : String? = nil)
  end
end

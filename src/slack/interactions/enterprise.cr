struct Slack::Interactions::Enterprise
  include JSON::Serializable

  getter id : String
  getter name : String?

  def initialize(@id : String, @name : String? = nil)
  end
end

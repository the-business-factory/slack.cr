struct Slack::Interactions::Team
  include JSON::Serializable

  getter id : String
  getter domain : String?
  getter enterprise_id : String?

  def initialize(@id : String, @domain : String? = nil, @enterprise_id : String? = nil)
  end
end

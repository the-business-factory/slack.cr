require "json"

module Slack::Models::Auth
  struct Test
    include JSON::Serializable

    getter user_id : String
    getter bot_id : String?
    getter team_id : String?
    getter enterprise_id : String?
    getter url : String?
    getter team : String?
    getter user : String?
    getter is_enterprise_install : Bool?

    def initialize(@user_id : String, @bot_id : String? = nil, @team_id : String? = nil,
                   @enterprise_id : String? = nil, @url : String? = nil,
                   @team : String? = nil, @user : String? = nil,
                   @is_enterprise_install : Bool? = nil)
    end
  end
end

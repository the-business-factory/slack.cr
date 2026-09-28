module Slack::Api
  # A presence that `UsersSetPresence` can set.
  enum PresenceSetting
    # Slack sets the presence from the user's activity.
    Auto
    Away

    # The wire name, such as `away`.
    def wire_name : String
      to_s.downcase
    end
  end
end

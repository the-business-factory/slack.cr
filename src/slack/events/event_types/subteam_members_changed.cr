# Users were added to or removed from a user group.
# https://docs.slack.dev/reference/events/subteam_members_changed
struct Slack::Events::SubteamMembersChanged < Slack::Event
  getter subteam_id : String
  getter added_users : Array(String) = [] of String
  getter removed_users : Array(String) = [] of String
end

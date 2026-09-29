# :nodoc:
# The `team.info` response, which holds the workspace in `team`.
struct Slack::Models::TeamBody
  include JSON::Serializable
  include Slack::Api::Envelope

  getter team : Team
end

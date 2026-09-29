# A workspace from `team.info`. See https://docs.slack.dev/reference/methods/team.info.
#
# Only `id` and `name` are always present. `enterprise_id` and
# `enterprise_name` are present for a workspace in an Enterprise organization.
# `icon` stays raw JSON. Unknown fields are ignored.
struct Slack::Models::Team < Slack::Model
  getter id : String
  getter name : String
  getter domain : String?
  getter email_domain : String?
  getter url : String?
  getter icon : JSON::Any?
  getter avatar_base_url : String?
  getter is_verified : Bool?
  getter enterprise_id : String?
  getter enterprise_name : String?

  # :nodoc:
  # Reads the `team` object of a `team.info` response, and the response's
  # envelope fields.
  def self.from_api_response(body : String) : {Team, Api::Envelope}
    response = TeamBody.from_json(body)
    {response.team, response}
  end
end

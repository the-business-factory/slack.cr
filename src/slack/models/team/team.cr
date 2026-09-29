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

  # Reads the `team` object of a `team.info` response.
  def self.from_json(json : String | IO)
    keyed_json_object(json, find_key: "team")
  end

  # :nodoc:
  # Parses a `team.info` response once, with its envelope values.
  def self.from_api_response(body : String) : Api::DecodedResponse(Team)
    TeamBody.from_api_response(body).map(&.team)
  end
end

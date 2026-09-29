# An Events API `app_rate_limited` request. Slack sends it instead of event
# deliveries when the app would get more than 30,000 events in one hour from
# one workspace. It has no inner event and no `event_id`.
# https://docs.slack.dev/reference/events/app_rate_limited
struct Slack::AppRateLimited
  include JSON::Serializable

  getter type : String
  getter token : String
  getter team_id : String
  getter api_app_id : String

  # The minute when Slack started to limit events for `team_id`.
  @[JSON::Field(converter: Slack::EpochConverter)]
  getter minute_rate_limited : Time
end

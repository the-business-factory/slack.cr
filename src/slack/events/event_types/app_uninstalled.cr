struct Slack::Events::AppUninstalled < Slack::Event
  @[JSON::Field(emit_null: false)]
  property event_ts : String?
end

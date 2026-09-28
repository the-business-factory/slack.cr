# An inner event from an Events API `event_callback` envelope.
#
# Decoding selects a typed struct by the `type` field. A `type` that this
# library does not map decodes as `Slack::Events::Unknown`, so a new Slack
# event subscription does not break delivery. Match `Unknown` explicitly to
# handle those events.
abstract struct Slack::Event
  include JSON::Serializable
  include Slack::JSONRecords

  property type : String

  @[JSON::Field(emit_null: false)]
  property team_id : String?

  @[JSON::Field(key: "source_team", emit_null: false)]
  property source_team_id : String?

  @[JSON::Field(key: "user_team", emit_null: false)]
  property user_team_id : String?

  # Keep the explicit type dispatch together rather than split the discriminator mapping.
  # ameba:disable Metrics/CyclomaticComplexity
  def self.new(pull : JSON::PullParser) : Slack::Event
    location = pull.location
    raw = JSON::Any.new(pull)
    type = event_type(raw, location)
    json = raw.to_json

    case type
    when "app_deleted"              then Slack::Events::AppDeleted.from_json(json)
    when "app_home_opened"          then Slack::Events::AppHomeOpened.from_json(json)
    when "app_installed"            then Slack::Events::AppInstalled.from_json(json)
    when "app_mention"              then Slack::Events::AppMentioned.from_json(json)
    when "app_requested"            then Slack::Events::AppRequested.from_json(json)
    when "app_uninstalled"          then Slack::Events::AppUninstalled.from_json(json)
    when "channel_archive"          then Slack::Events::ChannelArchive.from_json(json)
    when "channel_created"          then Slack::Events::ChannelCreated.from_json(json)
    when "channel_deleted"          then Slack::Events::ChannelDeleted.from_json(json)
    when "channel_rename"           then Slack::Events::ChannelRename.from_json(json)
    when "channel_unarchive"        then Slack::Events::ChannelUnarchive.from_json(json)
    when "emoji_changed"            then Slack::Events::EmojiChanged.from_json(json)
    when "function_executed"        then Slack::Events::FunctionExecuted.from_json(json)
    when "link_shared"              then Slack::Events::LinkShared.from_json(json)
    when "member_joined_channel"    then Slack::Events::MemberJoinedChannel.from_json(json)
    when "member_left_channel"      then Slack::Events::MemberLeftChannel.from_json(json)
    when "message"                  then Slack::Events::MessageFactory.from_json(json)
    when "message_metadata_deleted" then Slack::Events::MessageMetadataDeleted.from_json(json)
    when "message_metadata_posted"  then Slack::Events::MessageMetadataPosted.from_json(json)
    when "message_metadata_updated" then Slack::Events::MessageMetadataUpdated.from_json(json)
    when "pin_added"                then Slack::Events::PinAdded.from_json(json)
    when "pin_removed"              then Slack::Events::PinRemoved.from_json(json)
    when "reaction_added"           then Slack::Events::ReactionAdded.from_json(json)
    when "reaction_removed"         then Slack::Events::ReactionRemoved.from_json(json)
    when "subteam_created"          then Slack::Events::SubteamCreated.from_json(json)
    when "subteam_members_changed"  then Slack::Events::SubteamMembersChanged.from_json(json)
    when "subteam_self_added"       then Slack::Events::SubteamSelfAdded.from_json(json)
    when "subteam_self_removed"     then Slack::Events::SubteamSelfRemoved.from_json(json)
    when "subteam_updated"          then Slack::Events::SubteamUpdated.from_json(json)
    when "team_join"                then Slack::Events::TeamJoin.from_json(json)
    when "tokens_revoked"           then Slack::Events::TokensRevoked.from_json(json)
    when "user_change"              then Slack::Events::UserChange.from_json(json)
    when "user_status_changed"      then Slack::Events::UserStatusChanged.from_json(json)
    else                                 Slack::Events::Unknown.new(type, raw)
    end
  end

  private def self.event_type(raw : JSON::Any, location : Tuple(Int32, Int32)) : String
    object = raw.as_h? || raise JSON::SerializableError.new("Expected a JSON object for an event", "Slack::Event", nil, *location, nil)
    object["type"]?.try(&.as_s?) ||
      raise JSON::SerializableError.new("Missing string JSON discriminator field 'type'", "Slack::Event", nil, *location, nil)
  end
end

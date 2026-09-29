# `KNOWN_TYPES` publishes the plain message type for `message`, so the message
# selector must be defined before `discriminated_by` expands.
require "./events/event_types/message_factory"

# An inner event from an Events API `event_callback` envelope.
#
# Decoding selects a typed struct by the `type` field. A `type` that this
# library does not map decodes as `Slack::Events::Unknown`, so a new Slack
# event subscription does not break delivery. Match `Unknown` explicitly to
# handle those events.
abstract struct Slack::Event
  include JSON::Serializable
  include Slack::JSONRecords
  include Slack::Discriminated

  property type : String

  @[JSON::Field(emit_null: false)]
  property team_id : String?

  @[JSON::Field(key: "source_team", emit_null: false)]
  property source_team_id : String?

  @[JSON::Field(key: "user_team", emit_null: false)]
  property user_team_id : String?

  discriminated_by "type", {
    agent_session_stopped:            Slack::Events::AgentSessionStopped,
    agent_session_title_changed:      Slack::Events::AgentSessionTitleChanged,
    app_context_changed:              Slack::Events::AppContextChanged,
    app_deleted:                      Slack::Events::AppDeleted,
    app_home_opened:                  Slack::Events::AppHomeOpened,
    app_installed:                    Slack::Events::AppInstalled,
    app_mention:                      Slack::Events::AppMentioned,
    app_requested:                    Slack::Events::AppRequested,
    app_uninstalled:                  Slack::Events::AppUninstalled,
    assistant_thread_context_changed: Slack::Events::AssistantThreadContextChanged,
    assistant_thread_started:         Slack::Events::AssistantThreadStarted,
    channel_archive:                  Slack::Events::ChannelArchive,
    channel_created:                  Slack::Events::ChannelCreated,
    channel_deleted:                  Slack::Events::ChannelDeleted,
    channel_rename:                   Slack::Events::ChannelRename,
    channel_unarchive:                Slack::Events::ChannelUnarchive,
    emoji_changed:                    Slack::Events::EmojiChanged,
    function_executed:                Slack::Events::FunctionExecuted,
    link_shared:                      Slack::Events::LinkShared,
    member_joined_channel:            Slack::Events::MemberJoinedChannel,
    member_left_channel:              Slack::Events::MemberLeftChannel,
    message:                          Slack::Events::MessageFactory,
    message_metadata_deleted:         Slack::Events::MessageMetadataDeleted,
    message_metadata_posted:          Slack::Events::MessageMetadataPosted,
    message_metadata_updated:         Slack::Events::MessageMetadataUpdated,
    pin_added:                        Slack::Events::PinAdded,
    pin_removed:                      Slack::Events::PinRemoved,
    reaction_added:                   Slack::Events::ReactionAdded,
    reaction_removed:                 Slack::Events::ReactionRemoved,
    subteam_created:                  Slack::Events::SubteamCreated,
    subteam_members_changed:          Slack::Events::SubteamMembersChanged,
    subteam_self_added:               Slack::Events::SubteamSelfAdded,
    subteam_self_removed:             Slack::Events::SubteamSelfRemoved,
    subteam_updated:                  Slack::Events::SubteamUpdated,
    team_join:                        Slack::Events::TeamJoin,
    tokens_revoked:                   Slack::Events::TokensRevoked,
    user_change:                      Slack::Events::UserChange,
    user_status_changed:              Slack::Events::UserStatusChanged,
  }, fallback: Slack::Events::Unknown
end

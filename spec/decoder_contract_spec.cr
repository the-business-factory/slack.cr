require "./spec_helper"

# The contract that every `Slack::Decoder` meets. `DecoderContract.verify`
# defines the examples for one decoder. The calls at the end of this file run
# them for the default decoder (`Slack::Decoders::Fused`) and for
# `Slack::Decoders::Stdlib`.
#
# For each fixture, the decoder must give the type in `EVENT_TYPES` or
# `INTERACTION_TYPES`, and the decoded payload must re-encode to the input.
# A payload re-encodes to the input when the two JSON values are equivalent.
# Two JSON values are equivalent when:
#
# - Two scalars are equal. JSON value equality ignores key order and
#   whitespace.
# - Two arrays have the same size and equivalent items in the same order.
# - For each key of two objects, both values are present and equivalent. A
#   `null` value is the same as an absent key, because the typed models omit
#   a `nil` field.
#
# The payload of a fallback type (`Events::Unknown`, `Message::Unmapped`, and
# `Interactions::Unknown`) keeps its JSON, so there a `null` value and an
# absent key are different.
#
# Each other difference fails the example, unless `KNOWN_DIFFERENCES` lists
# it for that fixture. A listed difference that does not occur also fails, so
# the list stays current when a model gains a field.
#
# Each malformed fixture must raise the error class and reason in `MALFORMED`
# with every decoder. The message text comes from the JSON parser, so each
# decoder gives its own expected messages.
module DecoderContract
  extend Spec::Methods

  FIXTURES = "spec/fixtures"

  # Known differences between the input and the re-encoded output, by fixture.
  KNOWN_DIFFERENCES = {
    # Typed models keep only the fields they declare. Only `Events::Unknown`,
    # `Message::Unmapped`, and `Interactions::Unknown` keep unknown keys
    # (decision 10: no `JSON::Serializable::Unmapped` on typed events).
    "events/app_home_opened.json"                      => ["$.event.event_ts: dropped"],
    "events/app_mention_thread.json"                   => ["$.event.client_msg_id: dropped"],
    "events/message/assistant_app_thread_changed.json" => [
      "$.event.message.edited: dropped",
      "$.event.message.is_locked: dropped",
      "$.event.message.latest_reply: dropped",
      "$.event.message.reply_count: dropped",
      "$.event.message.reply_users: dropped",
      "$.event.message.reply_users_count: dropped",
      "$.event.message.thread_ts: dropped",
      "$.event.message.type: dropped",
      "$.event.message.user: dropped",
      "$.event.previous_message.is_locked: dropped",
      "$.event.previous_message.latest_reply: dropped",
      "$.event.previous_message.reply_count: dropped",
      "$.event.previous_message.reply_users: dropped",
      "$.event.previous_message.reply_users_count: dropped",
      "$.event.previous_message.thread_ts: dropped",
      "$.event.previous_message.type: dropped",
      "$.event.previous_message.user: dropped",
      # Declared defaults.
      "$.event.message.attachments: added []",
      "$.event.previous_message.attachments: added []",
    ],
    "events/message/bot_message.json"  => ["$.event.icons: dropped"],
    "events/message/channel_join.json" => ["$.event.user: dropped"],
    "events/message/file_share.json"   => [
      "$.event.client_msg_id: dropped",
      "$.event.display_as_bot: dropped",
      "$.event.upload: dropped",
      # Declared defaults.
      "$.authorizations: added []",
    ],
    "events/message/message_changed.json" => [
      "$.event.message.attachments[2].image_bytes: dropped",
      "$.event.message.attachments[2].image_height: dropped",
      "$.event.message.attachments[2].image_url: dropped",
      "$.event.message.attachments[2].image_width: dropped",
      "$.event.message.type: dropped",
      "$.event.message.user: dropped",
      "$.event.previous_message.type: dropped",
      "$.event.previous_message.user: dropped",
      # Declared defaults.
      "$.event.previous_message.attachments: added []",
    ],
    "events/message/message_replied.json" => [
      "$.event.message.replies: dropped",
      "$.event.message.reply_count: dropped",
      "$.event.message.thread_ts: dropped",
      "$.event.message.type: dropped",
      "$.event.message.user: dropped",
      # Declared defaults.
      "$.event.message.attachments: added []",
    ],
    "events/subteam_members_changed.json" => [
      "$.event.added_users_count: dropped",
      "$.event.date_previous_update: dropped",
      "$.event.date_update: dropped",
      "$.event.removed_users_count: dropped",
    ],
    "events/thread_broadcast.json" => [
      "$.event.blocks: dropped",
      "$.event.client_msg_id: dropped",
      "$.event.text: dropped",
      "$.event.user: dropped",
      # Declared defaults.
      "$.authorizations: added []",
    ],
    # A declared default: the model writes `false` or `[]` when Slack leaves
    # the field out or sends `null`. Other nilable fields stay absent.
    "credential_lifecycle/bot_revoked.json"    => ["$.event.tokens.oauth: added []"],
    "credential_lifecycle/tokens_revoked.json" => ["$.authorizations: added []"],
    "events/app_uninstalled.json"              => ["$.authorizations: added []"],
    "events/emoji_changed.json"                => ["$.event.names: added []"],
    "events/link_shared_composer.json"         => ["$.event.is_unfurl_refresh: added false"],
    "events/tokens_revoked.json"               => ["$.authorizations: added []"],
    "block_kit/phase_5_submission.json"        => ["$.response_urls: added []"],
    # A workflow token is a secret. The models read it but do not write it,
    # so logs and `to_json` output do not show it.
    "events/function_executed.json"                 => ["$.event.bot_access_token: dropped"],
    "interactions/block_actions_view_function.json" => ["$.bot_access_token: dropped"],
    # `Slack::Command` does not model the deprecated verification token or
    # `team_domain`, and it decodes `is_enterprise_install` to a `Bool`.
    "commands/encoded_names.txt" => [
      "$.is_enterprise_install: \"false\\n\" became false",
      "$.team_domain: dropped",
      "$.token: dropped",
    ],
    "commands/unencoded_names.txt" => [
      "$.is_enterprise_install: \"false\\n\" became false",
      "$.team_domain: dropped",
      "$.token: dropped",
    ],
    "socket_mode/slash_commands.json" => [
      "$.is_enterprise_install: \"false\" became false",
      "$.team_domain: dropped",
      "$.token: dropped",
    ],
  }

  # The type that each event fixture decodes to. For a `Slack::VerifiedEvent`,
  # this is the type of its `event`.
  EVENT_TYPES = {
    "credential_lifecycle/app_uninstalled.json"        => Slack::Events::AppUninstalled,
    "credential_lifecycle/bot_revoked.json"            => Slack::Events::TokensRevoked,
    "credential_lifecycle/tokens_revoked.json"         => Slack::Events::TokensRevoked,
    "events/agent_session_stopped.json"                => Slack::Events::AgentSessionStopped,
    "events/agent_session_title_changed.json"          => Slack::Events::AgentSessionTitleChanged,
    "events/app_context_changed.json"                  => Slack::Events::AppContextChanged,
    "events/app_deleted.json"                          => Slack::Events::AppDeleted,
    "events/app_home_opened.json"                      => Slack::Events::AppHomeOpened,
    "events/app_installed.json"                        => Slack::Events::AppInstalled,
    "events/app_mention.json"                          => Slack::Events::AppMentioned,
    "events/app_mention_document.json"                 => Slack::Events::AppMentioned,
    "events/app_mention_thread.json"                   => Slack::Events::AppMentioned,
    "events/app_rate_limited.json"                     => Slack::AppRateLimited,
    "events/app_requested.json"                        => Slack::Events::AppRequested,
    "events/app_uninstalled.json"                      => Slack::Events::AppUninstalled,
    "events/assistant_thread_context_changed.json"     => Slack::Events::AssistantThreadContextChanged,
    "events/assistant_thread_started.json"             => Slack::Events::AssistantThreadStarted,
    "events/channel_archive.json"                      => Slack::Events::ChannelArchive,
    "events/channel_created.json"                      => Slack::Events::ChannelCreated,
    "events/channel_deleted.json"                      => Slack::Events::ChannelDeleted,
    "events/channel_rename.json"                       => Slack::Events::ChannelRename,
    "events/channel_unarchive.json"                    => Slack::Events::ChannelUnarchive,
    "events/emoji_changed.json"                        => Slack::Events::EmojiChanged,
    "events/emoji_removed.json"                        => Slack::Events::EmojiChanged,
    "events/function_executed.json"                    => Slack::Events::FunctionExecuted,
    "events/link_shared.json"                          => Slack::Events::LinkShared,
    "events/link_shared_composer.json"                 => Slack::Events::LinkShared,
    "events/member_joined_channel.json"                => Slack::Events::MemberJoinedChannel,
    "events/member_left_channel.json"                  => Slack::Events::MemberLeftChannel,
    "events/message.json"                              => Slack::Events::Message,
    "events/message/assistant_app_thread.json"         => Slack::Events::Message::AssistantAppThread,
    "events/message/assistant_app_thread_changed.json" => Slack::Events::Message::MessageChanged,
    "events/message/bot_add.json"                      => Slack::Events::Message::BotAdd,
    "events/message/bot_message.json"                  => Slack::Events::Message::BotMessage,
    "events/message/channel_join.json"                 => Slack::Events::Message::ChannelJoin,
    "events/message/channel_leave.json"                => Slack::Events::Message::ChannelLeave,
    "events/message/channel_name.json"                 => Slack::Events::Message::ChannelName,
    "events/message/channel_purpose.json"              => Slack::Events::Message::ChannelPurpose,
    "events/message/channel_topic.json"                => Slack::Events::Message::ChannelTopic,
    "events/message/file_share.json"                   => Slack::Events::Message::FileShare,
    "events/message/group_topic.json"                  => Slack::Events::Message::Unmapped,
    "events/message/me_message.json"                   => Slack::Events::Message::MeMessage,
    "events/message/message_changed.json"              => Slack::Events::Message::MessageChanged,
    "events/message/message_deleted.json"              => Slack::Events::Message::MessageDeleted,
    "events/message/message_replied.json"              => Slack::Events::Message::MessageReplied,
    "events/message/pinned_item.json"                  => Slack::Events::Message::PinnedItem,
    "events/message/unmapped_subtype.json"             => Slack::Events::Message::Unmapped,
    "events/message/unpinned_item.json"                => Slack::Events::Message::UnpinnedItem,
    "events/message_metadata_deleted.json"             => Slack::Events::MessageMetadataDeleted,
    "events/message_metadata_posted.json"              => Slack::Events::MessageMetadataPosted,
    "events/message_metadata_updated.json"             => Slack::Events::MessageMetadataUpdated,
    "events/pin_added.json"                            => Slack::Events::PinAdded,
    "events/pin_removed.json"                          => Slack::Events::PinRemoved,
    "events/reaction_added.json"                       => Slack::Events::ReactionAdded,
    "events/reaction_added_file.json"                  => Slack::Events::ReactionAdded,
    "events/reaction_added_file_comment.json"          => Slack::Events::ReactionAdded,
    "events/reaction_added_unknown_item.json"          => Slack::Events::ReactionAdded,
    "events/reaction_added_webhook_message.json"       => Slack::Events::ReactionAdded,
    "events/reaction_removed.json"                     => Slack::Events::ReactionRemoved,
    "events/reaction_removed_file.json"                => Slack::Events::ReactionRemoved,
    "events/subteam_created.json"                      => Slack::Events::SubteamCreated,
    "events/subteam_members_changed.json"              => Slack::Events::SubteamMembersChanged,
    "events/subteam_self_added.json"                   => Slack::Events::SubteamSelfAdded,
    "events/subteam_self_removed.json"                 => Slack::Events::SubteamSelfRemoved,
    "events/subteam_updated.json"                      => Slack::Events::SubteamUpdated,
    "events/team_join.json"                            => Slack::Events::TeamJoin,
    "events/thread_broadcast.json"                     => Slack::Events::Message::ThreadBroadcast,
    "events/tokens_revoked.json"                       => Slack::Events::TokensRevoked,
    "events/unknown_event.json"                        => Slack::Events::Unknown,
    "events/url_verification.json"                     => Slack::UrlVerification,
    "events/user_change.json"                          => Slack::Events::UserChange,
    "events/user_status_changed.json"                  => Slack::Events::UserStatusChanged,
    "request_authorizer/event_connect_workspace.json"  => Slack::Events::ReactionAdded,
    "request_authorizer/event_org_context.json"        => Slack::Events::ReactionRemoved,
    "socket_mode/events_api_app_mention.json"          => Slack::Events::AppMentioned,
  }

  # The type that each interaction fixture decodes to.
  INTERACTION_TYPES = {
    "block_kit/checkboxes_action.json"                    => Slack::Interactions::BlockAction,
    "block_kit/overflow_action.json"                      => Slack::Interactions::BlockAction,
    "block_kit/phase_4_home_action.json"                  => Slack::Interactions::BlockAction,
    "block_kit/phase_5_home_action.json"                  => Slack::Interactions::BlockAction,
    "block_kit/phase_5_message_action.json"               => Slack::Interactions::BlockAction,
    "block_kit/phase_5_modal_action.json"                 => Slack::Interactions::BlockAction,
    "block_kit/phase_5_submission.json"                   => Slack::Interactions::ViewSubmission,
    "interactions/block_actions_attachment.json"          => Slack::Interactions::BlockAction,
    "interactions/block_actions_context_clicks.json"      => Slack::Interactions::BlockAction,
    "interactions/block_actions_message.json"             => Slack::Interactions::BlockAction,
    "interactions/block_actions_view_function.json"       => Slack::Interactions::BlockAction,
    "interactions/message_action.json"                    => Slack::Interactions::MessageAction,
    "interactions/unknown_interaction.json"               => Slack::Interactions::Unknown,
    "interactions/view_closed_cleared.json"               => Slack::Interactions::ViewClosed,
    "interactions/view_submission_response_urls.json"     => Slack::Interactions::ViewSubmission,
    "request_authorizer/interaction_block_message.json"   => Slack::Interactions::BlockAction,
    "request_authorizer/interaction_block_view.json"      => Slack::Interactions::BlockAction,
    "request_authorizer/interaction_global_shortcut.json" => Slack::Interactions::Shortcut,
    "request_authorizer/interaction_message_action.json"  => Slack::Interactions::MessageAction,
    "request_authorizer/interaction_view_closed.json"     => Slack::Interactions::ViewClosed,
    "request_authorizer/interaction_view_submission.json" => Slack::Interactions::ViewSubmission,
    "socket_mode/interactive_block_actions.json"          => Slack::Interactions::BlockAction,
  }

  # The types that keep their payload JSON unchanged.
  FALLBACK_TYPES = [Slack::Events::Unknown, Slack::Events::Message::Unmapped, Slack::Interactions::Unknown]

  # The error that each malformed fixture raises with every decoder: the
  # error class, and for `Slack::Auth::RequestAuthorizationError` the reason.
  # A `JSON::ParseException` here excludes its subclass `JSON::SerializableError`.
  MALFORMED = {
    "malformed/events/truncated.json"                          => "JSON::ParseException",
    "malformed/events/array_body.json"                         => "JSON::ParseException",
    "malformed/events/missing_event.json"                      => "JSON::SerializableError",
    "malformed/events/app_mention_numeric_ts.json"             => "JSON::SerializableError",
    "malformed/events/channel_topic_missing_topic.json"        => "JSON::SerializableError",
    "malformed/events/url_verification_missing_challenge.json" => "JSON::SerializableError",
    "malformed/interactions/missing_type.json"                 => "JSON::SerializableError",
    "malformed/interactions/array_root.json"                   => "JSON::SerializableError",
    "malformed/interactions/block_actions_string_user.json"    => "JSON::SerializableError",
    "malformed/interactions/unknown_empty_user.json"           => "JSON::SerializableError",
    "malformed/interactions/duplicate_payload.txt"             => "Slack::Auth::RequestAuthorizationError (invalid_payload)",
    "malformed/commands/duplicate_team_id.txt"                 => "Slack::Auth::RequestAuthorizationError (duplicate_routing_field)",
    "malformed/commands/invalid_install_kind.txt"              => "Slack::Auth::RequestAuthorizationError (invalid_install_kind)",
    "malformed/commands/missing_command.txt"                   => "JSON::SerializableError",
  }

  # The full error that `Slack::Decoders::Stdlib` raises for each malformed
  # fixture. The JSON parser writes the message text (token wording, line,
  # and column), so each decoder has its own list.
  STDLIB_ERRORS = {
    "malformed/events/truncated.json" => <<-ERROR,
      JSON::ParseException: Unexpected token: <EOF> at line 1, column 100
      ERROR
    "malformed/events/array_body.json" => <<-ERROR,
      JSON::ParseException: Expected BeginObject but was BeginArray at line 1, column 2
      ERROR
    "malformed/events/missing_event.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: event
        parsing Slack::VerifiedEvent#event at line 1, column 1
      ERROR
    "malformed/events/app_mention_numeric_ts.json" => <<-ERROR,
      JSON::SerializableError: Expected String but was Int at line 1, column 84
        parsing Slack::Events::AppMentioned#ts at line 1, column 69
        parsing Slack::VerifiedEvent#event at line 5, column 3
      ERROR
    "malformed/events/channel_topic_missing_topic.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: topic
        parsing Slack::Events::Message::ChannelTopic#topic at line 1, column 1
        parsing Slack::VerifiedEvent#event at line 5, column 3
      ERROR
    "malformed/events/channel_created_out_of_range.json" => <<-ERROR,
      JSON::SerializableError: Unix time out of range at line 1, column 78
        parsing Slack::EventData::Channel#created at line 1, column 68
        parsing Slack::Events::ChannelCreated#channel at line 1, column 27
        parsing Slack::VerifiedEvent#event at line 5, column 3
      ERROR
    "malformed/events/url_verification_missing_challenge.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: challenge
        parsing Slack::UrlVerification#challenge at line 1, column 1
      ERROR
    "malformed/interactions/missing_type.json" => <<-ERROR,
      JSON::SerializableError: Missing string JSON discriminator field 'type'
        parsing Slack::Interaction at line 1, column 1
      ERROR
    "malformed/interactions/array_root.json" => <<-ERROR,
      JSON::SerializableError: Expected a JSON object
        parsing Slack::Interaction at line 1, column 1
      ERROR
    "malformed/interactions/block_actions_string_user.json" => <<-ERROR,
      JSON::SerializableError: Expected BeginObject but was String at line 1, column 119
        parsing Slack::Interactions::User at line 1, column 106
        parsing Slack::Interactions::BlockAction#user at line 1, column 99
      ERROR
    "malformed/interactions/unknown_empty_user.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: id
        parsing Slack::Interactions::User#id at line 1, column 1
      ERROR
    "malformed/interactions/duplicate_payload.txt" => <<-ERROR,
      Slack::Auth::RequestAuthorizationError: Authentication failure: InvalidIdentity (invalid_payload)
      ERROR
    "malformed/commands/duplicate_team_id.txt" => <<-ERROR,
      Slack::Auth::RequestAuthorizationError: Authentication failure: InvalidIdentity (duplicate_routing_field)
      ERROR
    "malformed/commands/invalid_install_kind.txt" => <<-ERROR,
      Slack::Auth::RequestAuthorizationError: Authentication failure: InvalidIdentity (invalid_install_kind)
      ERROR
    "malformed/commands/missing_command.txt" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: command
        parsing Slack::Command#command at line 1, column 1
      ERROR
  }

  # The full error that `Slack::Decoders::Fused` raises for each malformed
  # fixture. FusedJSON reports lines and columns in the original payload. The
  # trace names the internal envelope type that holds the concrete event.
  FUSED_ERRORS = {
    "malformed/events/truncated.json" => <<-ERROR,
      FusedJSON::ParseError: expected ',' or '}' in object at line 1, column 100
      ERROR
    "malformed/events/array_body.json" => <<-ERROR,
      FusedJSON::ParseError: expected BeginObject, found BeginArray at line 1, column 1
      ERROR
    "malformed/events/missing_event.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: event
        parsing Slack::VerifiedEvent#event at line 1, column 1
      ERROR
    "malformed/events/app_mention_numeric_ts.json" => <<-ERROR,
      JSON::SerializableError: expected String, found Int at line 9, column 11
        parsing Slack::Events::AppMentioned#ts at line 9, column 5
        parsing Slack::Decoders::Fused::Envelope(Slack::Events::AppMentioned)#event at line 5, column 3
      ERROR
    "malformed/events/channel_topic_missing_topic.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: topic
        parsing Slack::Events::Message::ChannelTopic#topic at line 5, column 12
        parsing Slack::Decoders::Fused::Envelope(Slack::Events::Message::ChannelTopic)#event at line 5, column 3
      ERROR
    "malformed/events/url_verification_missing_challenge.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: challenge
        parsing Slack::UrlVerification#challenge at line 1, column 1
      ERROR
    "malformed/interactions/missing_type.json" => <<-ERROR,
      JSON::SerializableError: Missing string JSON discriminator field 'type'
        parsing Slack::Interaction at line 1, column 1
      ERROR
    "malformed/interactions/array_root.json" => <<-ERROR,
      JSON::SerializableError: Expected a JSON object
        parsing Slack::Interaction at line 1, column 1
      ERROR
    "malformed/interactions/block_actions_string_user.json" => <<-ERROR,
      JSON::SerializableError: Expected BeginObject but was String at line 5, column 11
        parsing Slack::Interactions::User at line 5, column 11
        parsing Slack::Interactions::BlockAction#user at line 5, column 3
      ERROR
    "malformed/interactions/unknown_empty_user.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: id
        parsing Slack::Interactions::User#id at line 1, column 1
      ERROR
    "malformed/interactions/duplicate_payload.txt" => <<-ERROR,
      Slack::Auth::RequestAuthorizationError: Authentication failure: InvalidIdentity (invalid_payload)
      ERROR
    "malformed/commands/duplicate_team_id.txt" => <<-ERROR,
      Slack::Auth::RequestAuthorizationError: Authentication failure: InvalidIdentity (duplicate_routing_field)
      ERROR
    "malformed/commands/invalid_install_kind.txt" => <<-ERROR,
      Slack::Auth::RequestAuthorizationError: Authentication failure: InvalidIdentity (invalid_install_kind)
      ERROR
    "malformed/commands/missing_command.txt" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: command
        parsing Slack::Command#command at line 1, column 1
      ERROR
  }

  # A message whose `text` is a number and then a string. Slack does not send
  # duplicate keys, so the decoders may differ here, and do: the stdlib
  # decoder keeps the last value, and FusedJSON rejects the first one while
  # it decodes. The per-decoder outcome pins the difference, so a change in
  # either parser shows.
  DUPLICATE_FIELD = "malformed/events/message_duplicate_text.json"

  # The outcome of `DUPLICATE_FIELD` with `Slack::Decoders::Stdlib`.
  STDLIB_DUPLICATE_FIELD = "decoded text: hello"

  # The outcome of `DUPLICATE_FIELD` with `Slack::Decoders::Fused`.
  FUSED_DUPLICATE_FIELD = <<-ERROR
    JSON::SerializableError: expected String, found Int at line 5, column 89
      parsing Slack::Events::Message#text at line 5, column 81
      parsing Slack::Decoders::Fused::Envelope(Slack::Events::Message)#event at line 5, column 3
    ERROR

  # Defines the contract examples for *decoder*. *errors* gives the full
  # error, as `describe_error` writes it, for each `MALFORMED` fixture.
  # *duplicate_field* gives the outcome for `DUPLICATE_FIELD`.
  def self.verify(decoder : Slack::Decoder, errors : Hash(String, String), duplicate_field : String) : Nil
    describe "#{decoder.class} decoder contract" do
      describe "decodes and re-encodes each event fixture" do
        it "has an expected type for each event fixture" do
          EVENT_TYPES.keys.sort!.should eq(event_fixtures + ["socket_mode/events_api_app_mention.json"])
        end

        event_fixtures.each do |path|
          it path do
            body = read(path)
            assert_event(path, body, decoder.event(body))
          end
        end

        it "socket_mode/events_api_app_mention.json" do
          body = socket_mode_payload("socket_mode/events_api_app_mention.json")
          assert_event("socket_mode/events_api_app_mention.json", body, decoder.event(body))
        end
      end

      describe "decodes and re-encodes each interaction fixture as a form and as JSON" do
        it "has an expected type for each interaction fixture" do
          INTERACTION_TYPES.keys.sort!.should eq(interaction_fixtures + ["socket_mode/interactive_block_actions.json"])
        end

        interaction_fixtures.each do |path|
          it path do
            body = read(path)
            assert_interaction(path, body, decoder.interaction(form_payload(body)))
            assert_interaction(path, body, decoder.interaction(body, :json))
          end
        end

        it "socket_mode/interactive_block_actions.json" do
          body = socket_mode_payload("socket_mode/interactive_block_actions.json")
          assert_interaction("socket_mode/interactive_block_actions.json", body, decoder.interaction(body, :json))
        end
      end

      # `to_json` leaves out these secrets, so the round trip cannot check them.
      it "decodes the workflow tokens that to_json leaves out" do
        envelope = decoder.event(read("events/function_executed.json")).should be_a(Slack::VerifiedEvent)
        event = envelope.event.should be_a(Slack::Events::FunctionExecuted)
        event.bot_access_token.value.should eq("xwfp-synthetic-function-token")

        body = read("interactions/block_actions_view_function.json")
        [decoder.interaction(form_payload(body)), decoder.interaction(body, :json)].each do |decoded|
          action = decoded.should be_a(Slack::Interactions::BlockAction)
          action.bot_access_token.should_not(be_nil).value.should eq("xwfp-synthetic-workflow-token")
        end
      end

      describe "re-encodes each slash command fixture" do
        Dir.glob("#{FIXTURES}/commands/*.txt").sort.each do |file|
          path = relative(file)
          it path do
            body = read(path)
            assert_round_trip(path, form_as_json(body), decoder.command(body))
          end
        end

        it "socket_mode/slash_commands.json" do
          body = socket_mode_payload("socket_mode/slash_commands.json")
          assert_round_trip("socket_mode/slash_commands.json", body, decoder.command(body, :json))
        end
      end

      describe "raises the expected error for each malformed fixture" do
        it "has an expected error for each malformed fixture" do
          errors.keys.sort!.should eq(MALFORMED.keys.sort!)
        end

        MALFORMED.each do |path, expected|
          it path do
            decode_malformed(decoder, path).each do |error|
              error_kind(error).should eq(expected)
              describe_error(error).should eq(errors[path]?)
            end
          end
        end
      end

      it "gives its own outcome for a duplicate field of another JSON type (#{DUPLICATE_FIELD})" do
        duplicate_field_outcome(decoder).should eq(duplicate_field)
      end
    end
  end

  # Returns the differences between *input* and *output*, sorted. The subtree
  # at *strict_path* keeps `null` values. See the module documentation for the
  # rules.
  def self.differences(input : JSON::Any, output : JSON::Any, strict_path : String? = nil) : Array(String)
    differences = [] of String
    collect(input, output, "$", strict_path == "$", strict_path, differences)
    differences.sort
  end

  private def self.collect(input : JSON::Any, output : JSON::Any, path : String, strict : Bool,
                           strict_path : String?, differences : Array(String)) : Nil
    input_object = input.as_h?
    output_object = output.as_h?
    return collect_object(input_object, output_object, path, strict, strict_path, differences) if input_object && output_object

    input_array = input.as_a?
    output_array = output.as_a?
    return collect_array(input_array, output_array, path, strict, strict_path, differences) if input_array && output_array

    differences << "#{path}: #{input.to_json} became #{output.to_json}" unless input == output
  end

  private def self.collect_object(input : Hash(String, JSON::Any), output : Hash(String, JSON::Any), path : String,
                                  strict : Bool, strict_path : String?, differences : Array(String)) : Nil
    (input.keys | output.keys).each do |key|
      key_path = "#{path}.#{key}"
      key_strict = strict || key_path == strict_path
      input_value = key_strict ? input[key]? : present(input, key)
      output_value = key_strict ? output[key]? : present(output, key)
      if input_value && output_value
        collect(input_value, output_value, key_path, key_strict, strict_path, differences)
      elsif input_value
        differences << "#{key_path}: dropped"
      elsif output_value
        differences << "#{key_path}: added #{output_value.to_json}"
      end
    end
  end

  private def self.collect_array(input : Array(JSON::Any), output : Array(JSON::Any), path : String,
                                 strict : Bool, strict_path : String?, differences : Array(String)) : Nil
    return differences << "#{path}: #{input.size} items became #{output.size}" unless input.size == output.size

    input.each_with_index do |item, index|
      collect(item, output[index], "#{path}[#{index}]", strict, strict_path, differences)
    end
  end

  private def self.present(object : Hash(String, JSON::Any), key : String) : JSON::Any?
    value = object[key]?
    value unless value.nil? || value.raw.nil?
  end

  private def self.assert_event(path : String, input : String,
                                decoded : Slack::VerifiedEvent | Slack::UrlVerification | Slack::AppRateLimited) : Nil
    expected = EVENT_TYPES[path]?
    actual = decoded.is_a?(Slack::VerifiedEvent) ? decoded.event.class : decoded.class
    actual.should eq(expected)
    assert_round_trip(path, input, decoded, FALLBACK_TYPES.includes?(expected) ? "$.event" : nil)
  end

  private def self.assert_interaction(path : String, input : String, decoded : Slack::Interaction) : Nil
    expected = INTERACTION_TYPES[path]?
    decoded.class.should eq(expected)
    assert_round_trip(path, input, decoded, FALLBACK_TYPES.includes?(expected) ? "$" : nil)
  end

  private def self.assert_round_trip(path : String, input : String, decoded : JSON::Serializable,
                                     strict_path : String? = nil) : Nil
    actual = differences(JSON.parse(input), JSON.parse(decoded.to_json), strict_path)
    actual.should eq(KNOWN_DIFFERENCES.fetch(path, [] of String).sort)
  end

  private def self.decode_malformed(decoder : Slack::Decoder, path : String) : Array(Exception)
    body = read(path)
    kind = path.split('/')[1]
    case {kind, File.extname(path)}
    when {"events", ".json"}       then [capture { decoder.event(body) }]
    when {"interactions", ".json"} then [capture { decoder.interaction(form_payload(body)) }, capture { decoder.interaction(body, :json) }]
    when {"interactions", ".txt"}  then [capture { decoder.interaction(body) }]
    when {"commands", ".txt"}      then [capture { decoder.command(body) }]
    else                                raise ArgumentError.new("No decode rule for #{path}")
    end
  end

  private def self.duplicate_field_outcome(decoder : Slack::Decoder) : String
    envelope = decoder.event(read(DUPLICATE_FIELD)).should be_a(Slack::VerifiedEvent)
    message = envelope.event.should be_a(Slack::Events::Message)
    "decoded text: #{message.text}"
  rescue error : JSON::ParseException
    describe_error(error)
  end

  private def self.capture(&) : Exception
    yield
  rescue error
    error
  else
    fail "Expected the payload not to decode"
  end

  # Returns the error class that `MALFORMED` names for *error*, with the
  # reason of a `Slack::Auth::RequestAuthorizationError`.
  private def self.error_kind(error : Exception) : String
    case error
    when Slack::Auth::RequestAuthorizationError then "#{error.class} (#{error.reason})"
    when JSON::SerializableError                then "JSON::SerializableError"
    when JSON::ParseException                   then "JSON::ParseException"
    else                                             error.class.to_s
    end
  end

  private def self.describe_error(error : Exception) : String
    description = "#{error.class}: #{error.message}"
    return description unless error.is_a?(Slack::Auth::RequestAuthorizationError)

    "#{description} (#{error.reason})"
  end

  private def self.event_fixtures : Array(String)
    Dir.glob(
      "#{FIXTURES}/events/**/*.json",
      "#{FIXTURES}/credential_lifecycle/*.json",
      "#{FIXTURES}/request_authorizer/event_*.json",
    ).sort.map { |file| relative(file) }
  end

  private def self.interaction_fixtures : Array(String)
    Dir.glob(
      "#{FIXTURES}/interactions/*.json",
      "#{FIXTURES}/request_authorizer/interaction_*.json",
      "#{FIXTURES}/block_kit/*_action.json",
      "#{FIXTURES}/block_kit/phase_5_submission.json",
    ).sort.map { |file| relative(file) }
  end

  private def self.relative(file : String) : String
    file.lchop("#{FIXTURES}/")
  end

  private def self.read(path : String) : String
    File.read("#{FIXTURES}/#{path}")
  end

  # Returns the payload that `SocketModeReceiver` gives the decoder.
  private def self.socket_mode_payload(path : String) : String
    envelope = Slack::SocketMode::Frame.parse(read(path)).should be_a(Slack::SocketMode::Envelope)
    envelope.payload_json
  end

  # Returns an HTTP interaction body: *json* in the one `payload` field.
  private def self.form_payload(json : String) : String
    URI::Params.encode({"payload" => json})
  end

  # Returns the fields of a slash command form as a JSON object of strings.
  private def self.form_as_json(body : String) : String
    object = {} of String => String
    URI::Params.parse(body).each { |key, value| object[key] = value }
    object.to_json
  end
end

DecoderContract.verify(Slack::Decoder.default, DecoderContract::FUSED_ERRORS, DecoderContract::FUSED_DUPLICATE_FIELD)
DecoderContract.verify(Slack::Decoders::Stdlib.new, DecoderContract::STDLIB_ERRORS, DecoderContract::STDLIB_DUPLICATE_FIELD)

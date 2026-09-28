require "../spec_helper"

private def catalog_event(name : String) : Slack::Event
  envelope = Slack::Events.parse(File.read("spec/fixtures/events/#{name}.json")).should be_a(Slack::VerifiedEvent)
  envelope.event
end

describe "App event catalog" do
  it "decodes app lifecycle events with the app and actor IDs" do
    installed = catalog_event("app_installed").should be_a(Slack::Events::AppInstalled)
    installed.app_id.should eq "A-INSTALLED"
    installed.app_name.should eq "synthetic-admin-app"
    installed.app_owner_id.should eq "U-OWNER"
    installed.user_id.should eq "U-INSTALLER"
    installed.team_id.should eq "E-SYNTHETIC"
    installed.team_domain.should eq "synthetic-enterprise"

    deleted = catalog_event("app_deleted").should be_a(Slack::Events::AppDeleted)
    deleted.app_id.should eq "A-DELETED"
    deleted.event_ts.should eq "1789232400.000200"

    requested = catalog_event("app_requested").should be_a(Slack::Events::AppRequested)
    requested.app_request["app"]["id"].as_s.should eq "A-REQUESTED"
    requested.app_request["user"]["id"].as_s.should eq "U-REQUESTER"
  end

  it "decodes channel membership events with the member, channel, and inviter" do
    joined = catalog_event("member_joined_channel").should be_a(Slack::Events::MemberJoinedChannel)
    joined.user.should eq "W-JOINER"
    joined.channel.should eq "C-SYNTHETIC"
    joined.channel_type.should eq "C"
    joined.team.should eq "T-SYNTHETIC"
    joined.inviter.should eq "U-INVITER"
    joined.enterprise.should eq "E-SYNTHETIC"

    left = catalog_event("member_left_channel").should be_a(Slack::Events::MemberLeftChannel)
    left.user.should eq "W-LEAVER"
    left.channel.should eq "G-SYNTHETIC"
    left.channel_type.should eq "G"
  end

  it "keeps the team_join and user change user objects as raw JSON" do
    joined = catalog_event("team_join").should be_a(Slack::Events::TeamJoin)
    joined.user["id"].as_s.should eq "U-NEWCOMER"

    changed = catalog_event("user_change").should be_a(Slack::Events::UserChange)
    changed.user["profile"]["status_text"].as_s.should eq "riding a train"

    status = catalog_event("user_status_changed").should be_a(Slack::Events::UserStatusChanged)
    status.user["id"].as_s.should eq "U-STATUS"
    status.event_ts.should eq "1789232400.000700"
  end

  it "decodes shared links with the values that chat.unfurl needs" do
    shared = catalog_event("link_shared").should be_a(Slack::Events::LinkShared)
    shared.channel.should eq "C-SYNTHETIC"
    shared.user.should eq "U-SHARER"
    shared.message_ts.should eq "1789232400.000300"
    shared.thread_ts.should eq "1789232300.000100"
    shared.unfurl_id.should eq "C-SYNTHETIC.1789232400.000300.synthetic"
    shared.source.should eq "conversations_history"
    shared.bot_user_member?.should be_true
    shared.unfurl_refresh?.should be_false
    shared.user_locale.should eq "en-US"
    shared.links.map { |link| {link.domain, link.url} }.should eq [
      {"example.com", "https://example.com/12345"},
      {"another-example.com", "https://yet.another-example.com/v/abcde"},
    ]
  end

  it "decodes a composer link without the fields Slack omits" do
    shared = catalog_event("link_shared_composer").should be_a(Slack::Events::LinkShared)
    shared.channel.should eq "COMPOSER"
    shared.bot_user_member?.should be_false
    shared.unfurl_refresh?.should be_false
    shared.unfurl_id.should be_nil
    shared.source.should be_nil
    shared.thread_ts.should be_nil
    shared.links.map(&.url).should eq ["https://example.com/67890"]
  end

  it "rejects a shared link without a URL" do
    body = File.read("spec/fixtures/events/link_shared_composer.json").sub(%("url": "https://example.com/67890"), %("href": "x"))
    expect_raises(JSON::SerializableError) { Slack::Events.parse(body) }
  end

  it "decodes channel lifecycle events" do
    created = catalog_event("channel_created").should be_a(Slack::Events::ChannelCreated)
    created.channel.id.should eq "C-CREATED"
    created.channel.name.should eq "fun"
    created.channel.created.should eq Time.unix(1789232400)
    created.channel.creator.should eq "U-CREATOR"

    renamed = catalog_event("channel_rename").should be_a(Slack::Events::ChannelRename)
    renamed.channel.name.should eq "new_name"
    renamed.channel.creator.should be_nil

    catalog_event("channel_deleted").should(be_a(Slack::Events::ChannelDeleted)).channel.should eq "C-DELETED"

    archived = catalog_event("channel_archive").should be_a(Slack::Events::ChannelArchive)
    {archived.channel, archived.user}.should eq({"C-ARCHIVED", "U-ARCHIVER"})
    restored = catalog_event("channel_unarchive").should be_a(Slack::Events::ChannelUnarchive)
    {restored.channel, restored.user}.should eq({"C-ARCHIVED", "U-RESTORER"})
  end

  it "decodes pin events with the pinned item as raw JSON" do
    added = catalog_event("pin_added").should be_a(Slack::Events::PinAdded)
    added.user.should eq "U-PINNER"
    added.channel_id.should eq "C-SYNTHETIC"
    added.item["message"]["text"].as_s.should eq "Pinned note"

    removed = catalog_event("pin_removed").should be_a(Slack::Events::PinRemoved)
    removed.channel_id.should eq "C-SYNTHETIC"
    removed.has_pins?.should be_false
  end

  it "decodes message metadata events with the event type and payload" do
    posted = catalog_event("message_metadata_posted").should be_a(Slack::Events::MessageMetadataPosted)
    posted.channel_id.should eq "C-SYNTHETIC"
    posted.message_ts.should eq "1789232400.000800"
    posted.app_id.should eq "A-POSTER"
    posted.metadata.event_type.should eq "task_created"
    posted.metadata.event_payload["priority"].as_s.should eq "HIGH"

    updated = catalog_event("message_metadata_updated").should be_a(Slack::Events::MessageMetadataUpdated)
    updated.previous_metadata.event_payload["priority"].as_s.should eq "HIGH"
    updated.metadata.event_payload["priority"].as_s.should eq "LOW"

    deleted = catalog_event("message_metadata_deleted").should be_a(Slack::Events::MessageMetadataDeleted)
    deleted.previous_metadata.event_type.should eq "task_created"
    deleted.deleted_ts.should eq "1789232400.001000"
  end

  it "decodes emoji changes by subtype" do
    renamed = catalog_event("emoji_changed").should be_a(Slack::Events::EmojiChanged)
    renamed.subtype.should eq "rename"
    renamed.old_name.should eq "grin"
    renamed.new_name.should eq "cheese-grin"
    renamed.names.should be_empty

    removed = catalog_event("emoji_removed").should be_a(Slack::Events::EmojiChanged)
    removed.subtype.should eq "remove"
    removed.names.should eq ["picard_facepalm", "other_emoji"]
    removed.name.should be_nil
  end

  it "decodes user group events with the group ID and raw group objects" do
    created = catalog_event("subteam_created").should be_a(Slack::Events::SubteamCreated)
    created.subteam["handle"].as_s.should eq "marketing-team"
    updated = catalog_event("subteam_updated").should be_a(Slack::Events::SubteamUpdated)
    updated.subteam["user_count"].as_i.should eq 2

    members = catalog_event("subteam_members_changed").should be_a(Slack::Events::SubteamMembersChanged)
    members.subteam_id.should eq "S-MARKETING"
    members.added_users.should eq ["U-ONE", "U-TWO"]
    members.removed_users.should eq ["U-OLD"]

    catalog_event("subteam_self_added").should(be_a(Slack::Events::SubteamSelfAdded)).subteam_id.should eq "S-MARKETING"
    catalog_event("subteam_self_removed").should(be_a(Slack::Events::SubteamSelfRemoved)).subteam_id.should eq "S-MARKETING"
  end

  it "reads a canvas document mention on an app_mention event" do
    mention = catalog_event("app_mention_document").should be_a(Slack::Events::AppMentioned)
    mention.subtype.should eq "document_mention"
    document = mention.document_mention.should_not be_nil
    document.file_id.should eq "F-CANVAS"
    document.section_id.should eq "temp:C:synthetic"
    document.mentioning_user_ids.should eq ["U-MENTIONER"]
  end
end

describe Slack::AppRateLimited do
  it "decodes the rate-limit envelope, which has no inner event" do
    limited = Slack::Events.parse(File.read("spec/fixtures/events/app_rate_limited.json")).should be_a(Slack::AppRateLimited)
    limited.team_id.should eq "T-SYNTHETIC"
    limited.api_app_id.should eq "A-SYNTHETIC"
    limited.minute_rate_limited.should eq Time.unix(1789232400)
  end
end

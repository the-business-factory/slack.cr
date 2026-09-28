require "../spec_helper"

# Fixtures follow https://docs.slack.dev/reference/events/app_mention and
# https://docs.slack.dev/reference/events/reaction_added, with synthetic IDs.
private def fixture_event(name : String) : Slack::Event
  envelope = Slack::Events.parse(File.read("spec/fixtures/events/#{name}.json")).should be_a(Slack::VerifiedEvent)
  envelope.event
end

private def reaction_json(item : String) : String
  %({"type":"reaction_added","user":"U-REACTOR","reaction":"eyes","item":#{item},"event_ts":"1789232400.000001"})
end

describe Slack::Events::AppMentioned do
  it "reads the message fields of a top-level mention" do
    mention = fixture_event("app_mention").should be_a(Slack::Events::AppMentioned)
    mention.channel.should eq "C-SYNTHETIC"
    mention.user.should eq "U-MENTIONER"
    mention.text.should eq "What is the hour of the pearl, <@U-BOT>?"
    mention.ts.should eq "1789232400.000016"
    mention.event_ts.should eq "1789232400000016"
    mention.thread_ts.should be_nil
    mention.team.should be_nil
    mention.blocks.should be_empty
    (mention.thread_ts || mention.ts).should eq "1789232400.000016"
  end

  it "reads the thread, team, and blocks of a mention in a thread" do
    mention = fixture_event("app_mention_thread").should be_a(Slack::Events::AppMentioned)
    mention.ts.should eq "1789232460.000200"
    mention.thread_ts.should eq "1789232400.000100"
    mention.team.should eq "T-SYNTHETIC"
    (mention.thread_ts || mention.ts).should eq "1789232400.000100"

    block = mention.blocks.first.should be_a(Slack::Interactions::RichText::Block)
    block.block_id.should eq "Bm1"
  end

  it "rejects a mention without its message timestamp" do
    json = %({"type":"app_mention","user":"U-MENTIONER","text":"hi","channel":"C-SYNTHETIC","event_ts":"1.2"})
    expect_raises(JSON::SerializableError, /ts/) { Slack::Event.from_json(json) }
  end
end

describe Slack::EventData::ReactionItem do
  it "decodes a reaction on a message, including one without an item author" do
    reaction = fixture_event("reaction_added_webhook_message").should be_a(Slack::Events::ReactionAdded)
    reaction.item_user.should be_nil
    item = reaction.item.should be_a(Slack::EventData::ReactionItem::Message)
    item.type.should eq "message"
    item.channel.should eq "C-SYNTHETIC"
    item.ts.should eq "1789232300.498405"
    item.channel_type.should eq "channel"
  end

  it "decodes reactions on a file and on a file comment" do
    file_reaction = fixture_event("reaction_added_file").should be_a(Slack::Events::ReactionAdded)
    file_reaction.item_user.should eq "U-UPLOADER"
    file_reaction.item.should(be_a(Slack::EventData::ReactionItem::File)).file.should eq "F-SYNTHETIC"

    comment_reaction = fixture_event("reaction_added_file_comment").should be_a(Slack::Events::ReactionAdded)
    comment = comment_reaction.item.should be_a(Slack::EventData::ReactionItem::FileComment)
    comment.file.should eq "F-SYNTHETIC"
    comment.file_comment.should eq "Fc-SYNTHETIC"
  end

  it "keeps an item type this library does not model as raw JSON" do
    reaction = fixture_event("reaction_added_unknown_item").should be_a(Slack::Events::ReactionAdded)
    item = reaction.item.should be_a(Slack::EventData::ReactionItem::Unknown)
    item.type.should eq "canvas_section"
    item.raw["section_id"].as_s.should eq "temp:C:synthetic"

    untyped = Slack::Event.from_json(reaction_json(%({"file":"F-SYNTHETIC"}))).should be_a(Slack::Events::ReactionAdded)
    untyped.item.should(be_a(Slack::EventData::ReactionItem::Unknown)).type.should be_nil
  end

  it "decodes the same typed item on reaction_removed" do
    reaction = fixture_event("reaction_removed_file").should be_a(Slack::Events::ReactionRemoved)
    reaction.reaction.should eq "eyes"
    reaction.item.should(be_a(Slack::EventData::ReactionItem::File)).file.should eq "F-SYNTHETIC"
  end

  it "rejects a malformed item so that request authorization reports an invalid payload" do
    [%({"type":"file"}), %({"type":"message","channel":"C-SYNTHETIC"}), %({"type":1}), %("message")].each do |item|
      expect_raises(JSON::SerializableError, /item/) { Slack::Event.from_json(reaction_json(item)) }
    end
  end
end

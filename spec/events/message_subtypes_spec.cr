require "../spec_helper"

private def message_event(subtype : String) : Slack::Event
  envelope = Slack::Events.parse(File.read("spec/fixtures/events/message/#{subtype}.json")).should be_a(Slack::VerifiedEvent)
  envelope.event
end

describe "Message subtypes" do
  it "decodes channel setting changes with the new values" do
    topic = message_event("channel_topic").should be_a(Slack::Events::Message::ChannelTopic)
    topic.user.should eq "U-EDITOR"
    topic.topic.should eq "hello world"

    purpose = message_event("channel_purpose").should be_a(Slack::Events::Message::ChannelPurpose)
    purpose.purpose.should eq "whatever"

    name = message_event("channel_name").should be_a(Slack::Events::Message::ChannelName)
    {name.old_name, name.name}.should eq({"random", "watercooler"})

    leave = message_event("channel_leave").should be_a(Slack::Events::Message::ChannelLeave)
    leave.user.should eq "U-LEAVER"
    leave.subtype.should eq "channel_leave"
  end

  it "decodes subtypes that carry only the fields in Slack's reference examples" do
    topic = message_event("channel_topic").should be_a(Slack::Events::Message::ChannelTopic)
    {topic.channel, topic.channel_type, topic.event_ts}.should eq({nil, nil, nil})
    topic.ts.should eq "1789232400.002000"

    pinned = message_event("pinned_item").should be_a(Slack::Events::Message::PinnedItem)
    pinned.channel.should eq "C-SYNTHETIC"
    {pinned.channel_type, pinned.event_ts}.should eq({nil, nil})

    replied = message_event("message_replied").should be_a(Slack::Events::Message::MessageReplied)
    replied.channel_type.should be_nil
    replied.event_ts.should eq "1789232400.002000"
  end

  it "decodes a /me message and reads its channel type when Slack sends one" do
    me = message_event("me_message").should be_a(Slack::Events::Message::MeMessage)
    me.text.should eq "is doing that thing"
    me.user.should eq "U-ACTOR"
    me.mpim?.should be_false

    body = File.read("spec/fixtures/events/message/me_message.json").sub(%("subtype": "me_message"), %("subtype": "me_message", "channel_type": "mpim"))
    envelope = Slack::Events.parse(body).should be_a(Slack::VerifiedEvent)
    in_group = envelope.event.should be_a(Slack::Events::Message::MeMessage)
    in_group.mpim?.should be_true
    in_group.public_channel?.should be_false
  end

  it "decodes a thread reply notice with the parent message" do
    replied = message_event("message_replied").should be_a(Slack::Events::Message::MessageReplied)
    replied.hidden?.should be_true
    replied.message.ts.should eq "1789232300.000100"
    replied.message.text.should eq "Parent message"
  end

  it "decodes pin notices with the item type and raw item" do
    pinned = message_event("pinned_item").should be_a(Slack::Events::Message::PinnedItem)
    pinned.user.should eq "U-PINNER"
    pinned.item_type.should eq "F"
    pinned.item["id"].as_s.should eq "F-SYNTHETIC"

    unpinned = message_event("unpinned_item").should be_a(Slack::Events::Message::UnpinnedItem)
    unpinned.item_type.should eq "G"
  end

  it "decodes an unmapped subtype as the base message with its subtype" do
    message = message_event("unmapped_subtype").should be_a(Slack::Events::Message)
    message.subtype.should eq "synthetic_future_subtype"
    message.channel.should eq "C-SYNTHETIC"
    message.channel_type.should be_nil
    message.user.should be_nil
    message.text.should be_nil
    message.blocks.should be_empty
  end

  it "decodes an unmapped subtype without a channel, as Slack's group_topic reference shows" do
    message = message_event("group_topic").should be_a(Slack::Events::Message)
    message.subtype.should eq "group_topic"
    message.channel.should be_nil
    message.user.should eq "U-EDITOR"
    message.ts.should eq "1789232400.002100"
  end

  it "keeps a message without a subtype as the base message" do
    message = message_event("../message").should be_a(Slack::Events::Message)
    message.subtype.should be_nil
    message.user.should eq "U016SQZLFEE"
  end

  it "rejects a message subtype that is not a string" do
    [%({"type":"message","subtype":1,"channel":"C1","channel_type":"im"}),
     %({"type":"message","subtype":{},"channel":"C1","channel_type":"im"})].each do |json|
      expect_raises(JSON::SerializableError) { Slack::Event.from_json(json) }
    end
  end
end

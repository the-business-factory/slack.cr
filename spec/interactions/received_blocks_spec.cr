require "../spec_helper"

module ReceivedBlocksSpec
  alias RB = Slack::Interactions::ReceivedBlocks
  alias RT = Slack::Interactions::RichText

  def self.fixture(name : String) : JSON::Any
    JSON.parse(File.read("spec/fixtures/block_kit/#{name}.json"))
  end

  def self.decode(json : String) : Array(Slack::Interactions::ReceivedBlock)
    RB.decode(JSON.parse(json), "message.blocks")
  end

  describe RB do
    it "reads message layout blocks and keeps an unknown block type opaque" do
      blocks = RB.decode(fixture("received_message")["blocks"], "message.blocks")
      blocks.size.should eq 7

      section = blocks[0].should be_a(RB::Section)
      section.block_id.should eq "request.summary"
      text = section.text.should_not be_nil
      {text.type, text.text, text.verbatim}.should eq({"mrkdwn", "*Request 42* from <@U-SYNTHETIC>", false})
      section.fields.map { |field| {field.type, field.text, field.emoji} }
        .should eq [{"mrkdwn", "*Owner*\nMorgan", nil}, {"plain_text", "Due Friday :calendar:", true}]
      accessory = section.accessory.should_not be_nil
      {accessory.type, accessory.action_id}.should eq({"overflow", "request.more"})
      accessory.raw["options"][0]["value"].should eq "snooze"

      blocks[1].should(be_a(RB::Divider)).block_id.should eq "Yq2Rt"

      actions = blocks[2].should be_a(RB::Actions)
      actions.block_id.should eq "request.decision"
      actions.elements.map { |element| {element.type, element.action_id} }
        .should eq [{"button", "request.approve"}, {"static_select", "request.priority"}, {"workflow_button", "request.escalate"}]

      context = blocks[3].should be_a(RB::Context)
      image = context.elements[0].should be_a(RB::ElementSummary)
      {image.type, image.action_id, image.raw["alt_text"].as_s}.should eq({"image", nil, "Morgan"})
      context.elements[1].should(be_a(Slack::Interactions::ReceivedText)).text.should eq "Filed 2 hours ago"

      rich_text = blocks[4].should be_a(RT::Block)
      rich_text.block_id.should eq "request.note"
      rich_text.elements.first.should(be_a(RT::Section)).elements[1].should(be_a(RT::User)).user_id.should eq "U-REVIEWER"

      container = blocks[5].should be_a(RB::Container)
      {container.block_id, container.width, container.is_collapsible, container.default_collapsed, container.has_header_divider}
        .should eq({"request.details", "wide", true, true, nil})
      container.title.try(&.text).should eq "Details"
      container.subtitle.try(&.type).should eq "mrkdwn"
      container.rich_text_title.should be_nil
      children = container.child_blocks
      header = children[0].should be_a(RB::Header)
      {header.block_id, header.text.text, header.level}.should eq({"details.heading", "Line items", nil})
      table = children[1].should be_a(RB::Table)
      table.block_id.should eq "details.items"
      table.column_settings.try(&.[1]["align"].as_s).should eq "right"
      rows = table.rows
      rows.size.should eq 3
      rows[0].map(&.should(be_a(RB::RawText)).text).should eq %w[Item Cost]
      cost = rows[1][1].should be_a(RB::RawNumber)
      {cost.value, cost.text}.should eq({1299.5, "$1,299.50"})
      rows[2][0].should(be_a(RT::Block)).elements.size.should eq 1
      rows[2][1].should(be_a(RB::RawNumber)).value.should eq 180_i64

      unknown = blocks[6].should be_a(RB::UnknownBlock)
      {unknown.type, unknown.raw["payload"]["level"].as_i}.should eq({"synthetic_future_block", 3})
    end

    it "reads view blocks, including input labels and element summaries" do
      blocks = RB.decode(fixture("received_view")["blocks"], "view.blocks")
      blocks.size.should eq 5

      header = blocks[0].should be_a(RB::Header)
      {header.text.text, header.level}.should eq({"New bug", 2})
      alert = blocks[1].should be_a(RB::Alert)
      {alert.block_id, alert.text.type, alert.text.text, alert.level}.should eq({"bug.warning", "mrkdwn", "Do *not* paste secrets", "warning"})

      summary = blocks[2].should be_a(RB::Input)
      {summary.block_id, summary.label.text, summary.hint.try(&.text), summary.optional, summary.dispatch_action}
        .should eq({"bug.summary", "Summary", "One line", false, true})
      {summary.element.type, summary.element.action_id}.should eq({"plain_text_input", "summary"})
      details = blocks[3].should be_a(RB::Input)
      {details.hint, details.optional, details.element.type}.should eq({nil, true, "rich_text_input"})

      image = blocks[4].should be_a(RB::Image)
      {image.block_id, image.alt_text, image.image_url, image.title.try(&.text), image.slack_file}
        .should eq({"bug.screenshot", "Screenshot", "https://example.com/screenshot.png", "Last crash", nil})
    end

    it "reads display-only blocks and keeps plan tasks and charts raw" do
      blocks = RB.decode(fixture("received_display_message")["blocks"], "message.blocks")
      blocks.size.should eq 9

      markdown = blocks[0].should be_a(RB::Markdown)
      {markdown.block_id, markdown.text}.should eq({"report.intro", "## Weekly report\n\n- **3** deploys"})
      file = blocks[1].should be_a(RB::File)
      {file.block_id, file.external_id, file.source}.should eq({"report.file", "report-2026-w39", "remote"})

      video = blocks[2].should be_a(RB::Video)
      {video.alt_text, video.title.text, video.title_url, video.description.try(&.text), video.video_url, video.thumbnail_url}
        .should eq({"Demo", "Demo", "https://example.com/demo", "Two minutes", "https://example.com/embed/demo", "https://example.com/demo.png"})
      {video.author_name, video.provider_name, video.provider_icon_url}.should eq({"Morgan", "ExampleTube", "https://example.com/icon.png"})

      data_table = blocks[3].should be_a(RB::DataTable)
      {data_table.caption, data_table.page_size, data_table.row_header_column_index}.should eq({"Open tickets", 10, 0})
      data_table.rows[1][1].should(be_a(RB::RawNumber)).value.should eq 3_i64

      chart = blocks[4].should be_a(RB::DataVisualization)
      {chart.title, chart.chart["type"].as_s}.should eq({"Deploys by service", "pie"})

      carousel = blocks[5].should be_a(RB::Carousel)
      card = carousel.elements.first.should be_a(RB::Card)
      {card.block_id, card.title.try(&.text), card.subtitle.try(&.text), card.body.try(&.text), card.subtext.try(&.text)}
        .should eq({"team.api", "*API*", "Platform", "2 deploys", "On call: Morgan"})
      {card.slack_icon.try(&.name), card.hero_image.try(&.type), card.icon}.should eq({"code", "image", nil})
      card.actions.map { |action| {action.type, action.action_id} }.should eq [{"button", "team.open"}]

      feedback = blocks[6].should be_a(RB::ContextActions)
      feedback.elements.map { |element| {element.type, element.action_id} }
        .should eq [{"feedback_buttons", "report.rate"}, {"icon_button", "report.delete"}]

      plan = blocks[7].should be_a(RB::Plan)
      {plan.block_id, plan.title, plan.tasks[0]["task_id"].as_s}.should eq({"report.plan", "Next steps", "t1"})
      task = blocks[8].should be_a(RB::TaskCard)
      {task.task_id, task.title, task.status}.should eq({"t2", "Summarize", "in_progress"})
      task.sources.map { |source| {source.type, source.url, source.text} }.should eq [{"url", "https://example.com/log", "log"}]
    end

    it "returns an empty list for absent or null blocks" do
      RB.decode(nil, "message.blocks").should be_empty
      RB.decode(JSON::Any.new(nil), "message.blocks").should be_empty
    end

    it "reads an absent or null task card source list as empty" do
      blocks = decode(<<-JSON)
        [{"type":"task_card","task_id":"t1","title":"Plan","status":"pending"},
         {"type":"task_card","task_id":"t2","title":"Run","status":"pending","sources":null}]
        JSON
      blocks.map(&.should(be_a(RB::TaskCard)).sources).should eq [[] of RB::TaskCard::Source, [] of RB::TaskCard::Source]
    end

    it "returns copies of received collections" do
      blocks = decode(<<-JSON)
        [{"type":"actions","elements":[{"type":"button","action_id":"a"}]},
         {"type":"container","child_blocks":[{"type":"divider"}]},
         {"type":"table","rows":[[{"type":"raw_text","text":"a"}]]}]
        JSON
      actions = blocks[0].should be_a(RB::Actions)
      actions.elements.clear
      actions.elements.size.should eq 1
      container = blocks[1].should be_a(RB::Container)
      container.child_blocks.clear
      container.child_blocks.size.should eq 1
      table = blocks[2].should be_a(RB::Table)
      table.rows.first.clear
      table.rows.first.size.should eq 1
    end

    it "does not apply outbound limits to received blocks" do
      long = "x" * 3100
      blocks = decode(%([{"type":"header","text":{"type":"plain_text","text":"#{long}"}},{"type":"actions","elements":[]}]))
      blocks[0].should(be_a(RB::Header)).text.text.size.should eq 3100
      blocks[1].should(be_a(RB::Actions)).elements.should be_empty
    end

    it "rejects malformed known blocks with the failing path" do
      {
        %({"type":"section"})                                                                                          => {"message.blocks", "array"},
        %([{"type":"actions","elements":{}}])                                                                          => {"message.blocks[0].elements", "array"},
        %([{"type":"header"}])                                                                                         => {"message.blocks[0].text", "text object"},
        %([{"type":"input","label":{"type":"plain_text","text":"L"}}])                                                 => {"message.blocks[0].element", "element object"},
        %([{"type":"actions","elements":[{"action_id":"a"}]}])                                                         => {"message.blocks[0].elements[0].type", "string"},
        %([{"type":"section","block_id":7}])                                                                           => {"message.blocks[0].block_id", "string or null"},
        %([{"type":"container","child_blocks":[{"type":"markdown"}]}])                                                 => {"message.blocks[0].child_blocks[0].text", "string"},
        %([{"type":"table","rows":[[{"type":"raw_number","text":"1"}]]}])                                              => {"message.blocks[0].rows[0][0].value", "number"},
        %([{"type":"table","rows":[{"type":"raw_text"}]}])                                                             => {"message.blocks[0].rows[0]", "array"},
        %([{"type":"plan","title":"Next"}])                                                                            => {"message.blocks[0].tasks", "array"},
        %([{"type":"task_card","task_id":"t","title":"T","status":"pending","sources":[{"type":"url","text":"log"}]}]) => {"message.blocks[0].sources[0].url", "string"},
        %([{"type":"card","slack_icon":{"type":"icon"}}])                                                              => {"message.blocks[0].slack_icon.name", "string"},
        %(["divider"])                                                                                                 => {"message.blocks[0]", "object"},
      }.each do |json, (path, expected)|
        error = expect_raises(Slack::Interactions::TypeMismatch) { decode(json) }
        {error.path, error.expected}.should eq({path, expected})
      end
    end
  end

  describe "received blocks in payloads" do
    it "reads the source message of a block action and a message shortcut" do
      message_json = File.read("spec/fixtures/block_kit/received_message.json")
      action = Slack::Interaction.from_json(%({"type":"block_actions","message":#{message_json}})).should be_a(Slack::Interactions::BlockAction)
      message = action.message.should_not be_nil
      {message.ts, message.thread_ts, message.text, message.user}
        .should eq({"1789232400.000100", "1789232300.000001", "Request 42 needs approval.", "U-BOT-SYNTHETIC"})
      message.blocks.map(&.class).should eq [RB::Section, RB::Divider, RB::Actions, RB::Context, RT::Block, RB::Container, RB::UnknownBlock]
      JSON.parse(action.to_json)["message"].should eq JSON.parse(message_json)

      shortcut = Slack::Interaction.from_json(%({"type":"message_action","message":#{message_json}})).should be_a(Slack::Interactions::MessageAction)
      shortcut.message.should_not(be_nil).blocks.size.should eq 7
    end

    it "reads view blocks and keeps a malformed block as a read-time error" do
      view_json = File.read("spec/fixtures/block_kit/received_view.json")
      submission = Slack::Interaction.from_json(%({"type":"view_submission","view":#{view_json}})).should be_a(Slack::Interactions::ViewSubmission)
      submission.view.should_not(be_nil).blocks.map(&.class).should eq [RB::Header, RB::Alert, RB::Input, RB::Input, RB::Image]

      action = Slack::Interaction.from_json(%({"type":"block_actions","view":{"id":"V1"},"message":{"ts":"1.2","blocks":[{"type":"header"}]}}))
        .should be_a(Slack::Interactions::BlockAction)
      action.view.should_not(be_nil).blocks.should be_empty
      message = action.message.should_not be_nil
      message.ts.should eq "1.2"
      error = expect_raises(Slack::Interactions::TypeMismatch) { message.blocks }
      error.path.should eq "message.blocks[0].text"
    end

    it "reads blocks in message events and message subtypes" do
      message = Slack::Event.from_json(<<-JSON).should be_a(Slack::Events::Message)
        {"type":"message","channel":"C1","channel_type":"channel","team":"T1","text":"hi","user":"U1","ts":"1.1","event_ts":"1.1",
         "blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*hi*"}}]}
        JSON
      message.blocks.first.should(be_a(RB::Section)).text.try(&.text).should eq "*hi*"
      plain = Slack::Event.from_json(%({"type":"message","channel":"C1","channel_type":"im","team":"T1","text":"hi","user":"U1","ts":"1.1","event_ts":"1.1"}))
      plain.should(be_a(Slack::Events::Message)).blocks.should be_empty

      file_share = Slack::Event.from_json(<<-JSON)
        {"type":"message","subtype":"file_share","channel":"C1","channel_type":"channel","event_ts":"1.2","ts":"1.2","user":"U1","files":[{"id":"F1"}],
         "blocks":[{"type":"rich_text","block_id":"n0t3","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"Build log attached"}]}]}]}
        JSON
      block = file_share.should(be_a(Slack::Events::Message::FileShare)).blocks.first.should be_a(RT::Block)
      block.elements.first.should(be_a(RT::Section)).elements.first.should(be_a(RT::Text)).text.should eq "Build log attached"

      changed = Slack::VerifiedEvent.from_json(File.read("spec/fixtures/events/message/message_changed.json")).event
        .should be_a(Slack::Events::Message::MessageChanged)
      changed.message.blocks.first.should(be_a(RT::Block)).block_id.should eq "uj=t"
      changed.previous_message.should_not(be_nil).blocks.size.should eq 1
    end

    it "decodes blocks once per instance and keeps them out of to_json" do
      json = <<-JSON
        {"type":"message","channel":"C1","channel_type":"channel","team":"T1","text":"hi","user":"U1","ts":"1.1",
         "blocks":[{"type":"divider","block_id":"d1"}]}
        JSON
      message = Slack::Event.from_json(json).should be_a(Slack::Events::Message)

      message.blocks.should be(message.blocks)
      JSON.parse(message.to_json).should eq JSON.parse(json)

      received = Slack::Interactions::ReceivedMessage.from_json(%({"ts":"1.2","blocks":[{"type":"divider"}]}))
      received.blocks.should be(received.blocks)
    end

    it "keeps a message event readable when its blocks are malformed" do
      # This captured file_share event carries a rich text section serialized as a string.
      event = Slack::VerifiedEvent.from_json(File.read("spec/fixtures/events/message/file_share.json")).event
      file_share = event.should be_a(Slack::Events::Message::FileShare)
      file_share.text.should eq "Such a zen job post."
      error = expect_raises(Slack::Interactions::TypeMismatch) { file_share.blocks }
      {error.path, error.expected}.should eq({"event.blocks[0].elements[0]", "object"})
    end
  end
end

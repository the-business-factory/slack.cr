require "../spec_helper"

module ReceivedRichTextSpec
  alias RT = Slack::Interactions::RichText

  def self.parse(json : String) : RT::Block
    RT::Block.new(JSON.parse(json), "message.blocks[0]")
  end

  def self.mismatch(json : String) : Slack::Interactions::TypeMismatch
    expect_raises(Slack::Interactions::TypeMismatch) { parse(json) }
  end

  describe RT::Block do
    it "reads a received tree, keeping unknown fields raw and unknown node types opaque" do
      block = RT::Block.new(JSON.parse(File.read("spec/fixtures/block_kit/rich_text_received.json")), "message.blocks[0]")
      block.block_id.should eq "Xy7="
      containers = block.elements
      containers.size.should eq 5

      section = containers[0].should be_a(RT::Section)
      leaves = section.elements
      text = leaves[0].should be_a(RT::Text)
      text.text.should eq "Release "
      style = text.style.should_not be_nil
      {style.bold, style.italic, style.code, style.client_highlight, style.highlight}.should eq({true, nil, false, true, nil})
      link = leaves[1].should be_a(RT::Link)
      {link.url, link.text, link.unsafe, link.style}.should eq({"https://example.com/r/9", "notes", true, nil})
      {link.from_llm, link.is_slack_url, link.truncated}.should eq({false, true, false})
      emoji = leaves[2].should be_a(RT::Emoji)
      {emoji.name, emoji.unicode}.should eq({"tada", "1f389"})
      user = leaves[3].should be_a(RT::User)
      user.user_id.should eq "U-SYNTHETIC"
      {user.from_llm, user.style.try(&.italic)}.should eq({true, true})
      leaves[4].should(be_a(RT::Usergroup)).usergroup_id.should eq "S-SYNTHETIC"
      channel = leaves[5].should be_a(RT::Channel)
      {channel.channel_id, channel.tab_id, channel.from_llm}.should eq({"C-SYNTHETIC", "Ct-SYNTHETIC", false})
      leaves[6].should(be_a(RT::Broadcast)).range.should eq "everyone"
      date = leaves[7].should be_a(RT::Date)
      {date.timestamp, date.format, date.timezone, date.url, date.fallback}.should eq({1_800_000_000_i64, "{date_num}", "UTC", nil, "2027-01-15"})
      leaves[8].should(be_a(RT::Color)).value.should eq "#E01E5A"
      team = leaves[9].should be_a(RT::Team)
      team_style = team.style.should_not be_nil
      {team.team_id, team_style.highlight, team_style.unlink, team_style.underline}.should eq({"T-SYNTHETIC", true, false, nil})
      file = leaves[10].should be_a(RT::File)
      {file.file_id, file.text, file.url, file.is_skill_invocation, file.style}.should eq({"F-SYNTHETIC", "plan.pdf", nil, false, nil})
      canvas = leaves[11].should be_a(RT::Canvas)
      {canvas.file_id, canvas.label, canvas.hide_title, canvas.section_id, canvas.text, canvas.url, canvas.is_skill_invocation}
        .should eq({"F-CANVAS", "Runbook", true, "temp:C:abc", nil, "https://example.com/docs/runbook", true})
      canvas.style.try(&.underline).should be_true
      workflow = leaves[12].should be_a(RT::WorkflowMention)
      {workflow.workflow_id, workflow.function_trigger_id, workflow.text, workflow.url, workflow.channel_id, workflow.ts}
        .should eq({"Wf-SYNTHETIC", "Ft-SYNTHETIC", "Request access", nil, "C-SYNTHETIC", "1710000000.000001"})
      citation = leaves[13].should be_a(RT::Unknown)
      {citation.type, citation.raw["url"].as_s}.should eq({"citation", "https://example.com/source"})

      list = containers[1].should be_a(RT::List)
      {list.style, list.indent, list.offset, list.border}.should eq({"bullet", 1, 0, 1})
      list.elements.map(&.elements.size).should eq [1, 0]
      code = containers[2].should be_a(RT::Preformatted)
      {code.border, code.language}.should eq({0, "json"})
      code.elements.first.should(be_a(RT::Text)).text.should eq "{}"
      quote = containers[3].should be_a(RT::Quote)
      quote.border.should be_nil
      quote.elements.first.should(be_a(RT::Text)).text.should eq "Ship it"
      containers[4].should(be_a(RT::Unknown)).type.should eq "rich_text_future_container"
    end

    it "returns copies of received collections" do
      block = parse(%({"type":"rich_text","elements":[{"type":"rich_text_list","style":"ordered","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"a"}]}]}]}))
      block.elements.clear
      list = block.elements.first.should be_a(RT::List)
      list.elements.clear
      list.elements.first.elements.clear
      block.elements.first.should(be_a(RT::List)).elements.first.elements.size.should eq 1
    end

    it "rejects malformed trees with the failing path" do
      {
        %({"type":"section","elements":[]})                                                                                                     => {"message.blocks[0].type", "rich_text"},
        %({"type":"rich_text"})                                                                                                                 => {"message.blocks[0].elements", "array"},
        %({"type":"rich_text","elements":{}})                                                                                                   => {"message.blocks[0].elements", "array"},
        %({"type":"rich_text","elements":[{"type":"text","text":"loose"}]})                                                                     => {"message.blocks[0].elements[0].type", "rich text container"},
        %({"type":"rich_text","elements":[{"elements":[]}]})                                                                                    => {"message.blocks[0].elements[0].type", "string"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"rich_text_quote","elements":[]}]}]})                 => {"message.blocks[0].elements[0].elements[0].type", "rich text element"},
        %({"type":"rich_text","elements":[{"type":"rich_text_list","style":"bullet","elements":[{"type":"text","text":"item"}]}]})              => {"message.blocks[0].elements[0].elements[0].type", "rich_text_section"},
        %({"type":"rich_text","elements":[{"type":"rich_text_list","elements":[]}]})                                                            => {"message.blocks[0].elements[0].style", "string"},
        %({"type":"rich_text","elements":[{"type":"rich_text_quote","border":"1","elements":[]}]})                                              => {"message.blocks[0].elements[0].border", "integer or null"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text"}]}]})                                          => {"message.blocks[0].elements[0].elements[0].text", "string"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"x","style":{"bold":"yes"}}]}]})        => {"message.blocks[0].elements[0].elements[0].style.bold", "boolean or null"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"date","timestamp":"soon","format":"{ago}"}]}]})      => {"message.blocks[0].elements[0].elements[0].timestamp", "integer"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"link","url":"https://example.com","unsafe":1}]}]})   => {"message.blocks[0].elements[0].elements[0].unsafe", "boolean or null"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[null]}]})                                                     => {"message.blocks[0].elements[0].elements[0]", "rich text object"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"team"}]}]})                                          => {"message.blocks[0].elements[0].elements[0].team_id", "string"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"workflow_mention","workflow_id":"W","text":"t"}]}]}) => {"message.blocks[0].elements[0].elements[0].function_trigger_id", "string"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"canvas","file_id":"F","hide_title":"no"}]}]})        => {"message.blocks[0].elements[0].elements[0].hide_title", "boolean or null"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"x","style":{"unlink":0}}]}]})          => {"message.blocks[0].elements[0].elements[0].style.unlink", "boolean or null"},
        %({"type":"rich_text","elements":[{"type":"rich_text_list","style":"bullet","elements":[{"type":"file","file_id":"F"}]}]})              => {"message.blocks[0].elements[0].elements[0].type", "rich_text_section"},
        %({"type":"rich_text","elements":[{"type":"canvas","file_id":"F"}]})                                                                    => {"message.blocks[0].elements[0].type", "rich text container"},
      }.each do |json, (path, expected)|
        error = mismatch(json)
        {error.path, error.expected}.should eq({path, expected})
      end
    end
  end
end

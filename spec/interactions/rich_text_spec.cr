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
      {style.bold, style.italic, style.code}.should eq({true, nil, false})
      style.raw["client_highlight"].as_bool.should be_true
      link = leaves[1].should be_a(RT::Link)
      {link.url, link.text, link.unsafe, link.style}.should eq({"https://example.com/r/9", "notes", true, nil})
      link.raw["from_llm"].as_bool.should be_false
      emoji = leaves[2].should be_a(RT::Emoji)
      {emoji.name, emoji.unicode}.should eq({"tada", "1f389"})
      user = leaves[3].should be_a(RT::User)
      user.user_id.should eq "U-SYNTHETIC"
      user.style.try(&.italic).should be_true
      leaves[4].should(be_a(RT::Usergroup)).usergroup_id.should eq "S-SYNTHETIC"
      leaves[5].should(be_a(RT::Channel)).channel_id.should eq "C-SYNTHETIC"
      leaves[6].should(be_a(RT::Broadcast)).range.should eq "everyone"
      date = leaves[7].should be_a(RT::Date)
      {date.timestamp, date.format, date.url, date.fallback}.should eq({1_800_000_000_i64, "{date_num}", nil, "2027-01-15"})
      leaves[8].should(be_a(RT::Color)).value.should eq "#E01E5A"
      team = leaves[9].should be_a(RT::Unknown)
      {team.type, team.raw["team_id"].as_s}.should eq({"team", "T-SYNTHETIC"})

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
        %({"type":"section","elements":[]})                                                                                                   => {"message.blocks[0].type", "rich_text"},
        %({"type":"rich_text"})                                                                                                               => {"message.blocks[0].elements", "array"},
        %({"type":"rich_text","elements":{}})                                                                                                 => {"message.blocks[0].elements", "array"},
        %({"type":"rich_text","elements":[{"type":"text","text":"loose"}]})                                                                   => {"message.blocks[0].elements[0].type", "rich text container"},
        %({"type":"rich_text","elements":[{"elements":[]}]})                                                                                  => {"message.blocks[0].elements[0].type", "string"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"rich_text_quote","elements":[]}]}]})               => {"message.blocks[0].elements[0].elements[0].type", "rich text element"},
        %({"type":"rich_text","elements":[{"type":"rich_text_list","style":"bullet","elements":[{"type":"text","text":"item"}]}]})            => {"message.blocks[0].elements[0].elements[0].type", "rich_text_section"},
        %({"type":"rich_text","elements":[{"type":"rich_text_list","elements":[]}]})                                                          => {"message.blocks[0].elements[0].style", "string"},
        %({"type":"rich_text","elements":[{"type":"rich_text_quote","border":"1","elements":[]}]})                                            => {"message.blocks[0].elements[0].border", "integer or null"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text"}]}]})                                        => {"message.blocks[0].elements[0].elements[0].text", "string"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"x","style":{"bold":"yes"}}]}]})      => {"message.blocks[0].elements[0].elements[0].style.bold", "boolean or null"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"date","timestamp":"soon","format":"{ago}"}]}]})    => {"message.blocks[0].elements[0].elements[0].timestamp", "integer"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"link","url":"https://example.com","unsafe":1}]}]}) => {"message.blocks[0].elements[0].elements[0].unsafe", "boolean or null"},
        %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[null]}]})                                                   => {"message.blocks[0].elements[0].elements[0]", "rich text object"},
      }.each do |json, (path, expected)|
        error = mismatch(json)
        {error.path, error.expected}.should eq({path, expected})
      end
    end
  end
end

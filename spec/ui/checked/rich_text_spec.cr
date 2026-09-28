require "../../spec_helper"

module RichTextSpec
  alias UI = Slack::UI::Checked
  alias RT = UI::RichText

  describe UI::Blocks::RichText do
    it "serializes every supported container and leaf as Slack documents them" do
      bold = RT::Style.new(bold: true, italic: false)
      block = UI::Blocks::RichText.new(block_id: "notes", elements: [
        RT::Section.new(elements: [
          RT::Text.new("Deploy ", style: RT::TextStyle.new(code: true, strike: false)),
          RT::Link.new("https://example.com/deploys/7", text: "run 7", unsafe: false, style: bold),
          RT::Emoji.new("wave", unicode: "1f44b"),
          RT::User.new("U-SYNTHETIC", style: bold),
          RT::Usergroup.new("S-SYNTHETIC"),
          RT::Channel.new("C-SYNTHETIC"),
          RT::Broadcast.new(RT::BroadcastRange::Here),
          RT::Date.new(1_800_000_000_i64, "{date_short} at {time}", url: "https://example.com/calendar", fallback: "Jan 15, 2027"),
          RT::Color.new("#36C5F0"),
        ]),
        RT::List.new(RT::ListStyle::Ordered, indent: 1, offset: 2, border: 0, elements: [
          RT::Section.new(elements: [RT::Text.new("Build")]),
          RT::Section.new(elements: [RT::Text.new("Ship", style: RT::TextStyle.new(italic: true))]),
        ]),
        RT::Preformatted.new(border: 1, language: "crystal", elements: [
          RT::Text.new("puts 1"),
          RT::Link.new("https://example.com"),
        ]),
        RT::Quote.new(border: 0, elements: [RT::Broadcast.new(RT::BroadcastRange::Channel, style: RT::Style.new(strike: true))]),
      ])

      # Authored from Slack's rich text block and element references, not from the serializer.
      JSON.parse(block.to_json).should eq JSON.parse(<<-JSON)
        {"type":"rich_text","block_id":"notes","elements":[
          {"type":"rich_text_section","elements":[
            {"type":"text","text":"Deploy ","style":{"code":true,"strike":false}},
            {"type":"link","url":"https://example.com/deploys/7","text":"run 7","unsafe":false,"style":{"bold":true,"italic":false}},
            {"type":"emoji","name":"wave","unicode":"1f44b"},
            {"type":"user","user_id":"U-SYNTHETIC","style":{"bold":true,"italic":false}},
            {"type":"usergroup","usergroup_id":"S-SYNTHETIC"},
            {"type":"channel","channel_id":"C-SYNTHETIC"},
            {"type":"broadcast","range":"here"},
            {"type":"date","timestamp":1800000000,"format":"{date_short} at {time}","url":"https://example.com/calendar","fallback":"Jan 15, 2027"},
            {"type":"color","value":"#36C5F0"}]},
          {"type":"rich_text_list","style":"ordered","indent":1,"offset":2,"border":0,"elements":[
            {"type":"rich_text_section","elements":[{"type":"text","text":"Build"}]},
            {"type":"rich_text_section","elements":[{"type":"text","text":"Ship","style":{"italic":true}}]}]},
          {"type":"rich_text_preformatted","border":1,"language":"crystal","elements":[
            {"type":"text","text":"puts 1"},{"type":"link","url":"https://example.com"}]},
          {"type":"rich_text_quote","border":0,"elements":[{"type":"broadcast","range":"channel","style":{"strike":true}}]}]}
        JSON
      JSON.parse(RT::List.new(RT::ListStyle::Bullet, elements: {RT::Section.new(elements: {RT::Text.new("One")})}).to_json)
        .should eq JSON.parse(%({"type":"rich_text_list","style":"bullet","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"One"}]}]}))
    end

    it "owns snapshots of every nested collection" do
      leaves = [RT::Text.new("first")] of RT::Element
      items = [RT::Section.new(elements: leaves)]
      code = [RT::Text.new("x = 1")] of RT::PreformattedElement
      containers = [RT::List.new(RT::ListStyle::Bullet, elements: items), RT::Preformatted.new(elements: code)] of RT::Container
      block = UI::Blocks::RichText.new(elements: containers)
      before = block.to_json

      leaves << RT::Text.new("added")
      items << RT::Section.new(elements: {RT::Text.new("added")})
      code.clear
      containers.clear
      list = block.elements.first.should be_a(RT::List)
      list.elements.clear
      list.elements.first.elements.clear
      block.elements.clear

      block.to_json.should eq before
    end

    it "rejects empty containers, required values, and out-of-range numbers" do
      section = RT::Section.new(elements: {RT::Text.new("ok")})
      error = expect_raises(UI::ValidationError) do
        UI::Blocks::RichText.new(block_id: "b" * 256, elements: [] of RT::Container)
      end
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"rich_text.elements.empty", "elements"},
        {"rich_text.block_id.too_long", "block_id"},
      ]
      UI::Blocks::RichText.new(block_id: "b" * 255, elements: {section}).validate.should be_empty

      expect_raises(UI::ValidationError) { RT::Section.new(elements: [] of RT::Element) }
        .issues.map(&.path).should eq ["elements"]
      expect_raises(UI::ValidationError) { RT::List.new(RT::ListStyle::Bullet, elements: {section}, border: 2) }
        .issues.map(&.code).should eq ["rich_text_list.border.invalid"]
      expect_raises(UI::ValidationError) { RT::List.new(RT::ListStyle::Ordered, elements: {section}, indent: -1, offset: -1) }
        .issues.map(&.path).should eq ["indent", "offset"]
      expect_raises(UI::ValidationError) { RT::User.new("") }
        .issues.map { |issue| {issue.code, issue.path} }.should eq [{"user.user_id.empty", "user_id"}]
      expect_raises(UI::ValidationError) { RT::Link.new("") }.issues.map(&.path).should eq ["url"]
      expect_raises(UI::ValidationError) { RT::Date.new(0_i64, "") }.issues.map(&.path).should eq ["format"]
      expect_raises(UI::ValidationError) { RT::Quote.new(elements: {RT::Text.new("quoted")}, border: -1) }
        .issues.map(&.path).should eq ["border"]
    end
  end
end

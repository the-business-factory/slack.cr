require "../spec_helper"

module RichTextSnapshotSpec
  alias UI = Slack::UI
  alias RT = UI::RichText

  it "posts owned rich text release notes matching independent request JSON" do
    items = [RT::Section.new(elements: {RT::Text.new("Faster builds")})]
    intro = [RT::Text.new("Release "), RT::Text.new("2.0", style: RT::TextStyle.new(bold: true)), RT::Text.new(" is live for ")] of RT::Element
    intro << RT::Usergroup.new("S-SYNTHETIC")
    builder = UI::MessageBuilder.new(fallback_text: "Release 2.0 is live")
    builder.header(UI.plain("Release 2.0"))
    builder.rich_text(block_id: "notes", elements: [
      RT::Section.new(elements: intro),
      RT::List.new(RT::ListStyle::Bullet, elements: items),
      RT::Quote.new(elements: {RT::Link.new("https://example.com/changelog", text: "Full changelog")}),
    ])
    request = Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC",
      message: builder.build)
    items << RT::Section.new(elements: {RT::Text.new("added later")})
    intro.clear
    builder.divider

    # Authored from Slack's rich text and chat.postMessage references, not from the serializer.
    expected = JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Release 2.0 is live","blocks":[
        {"type":"header","text":{"type":"plain_text","text":"Release 2.0"}},
        {"type":"rich_text","block_id":"notes","elements":[
          {"type":"rich_text_section","elements":[
            {"type":"text","text":"Release "},{"type":"text","text":"2.0","style":{"bold":true}},
            {"type":"text","text":" is live for "},{"type":"usergroup","usergroup_id":"S-SYNTHETIC"}]},
          {"type":"rich_text_list","style":"bullet","elements":[
            {"type":"rich_text_section","elements":[{"type":"text","text":"Faster builds"}]}]},
          {"type":"rich_text_quote","elements":[{"type":"link","url":"https://example.com/changelog","text":"Full changelog"}]}]}]}
      JSON
    JSON.parse(request.to_json).should eq expected
  end

  it "places the same rich text block in display modals and Home" do
    quote = RT::Quote.new(elements: {RT::Text.new("Read only")})
    wire = JSON.parse(%({"type":"rich_text","elements":[{"type":"rich_text_quote","elements":[{"type":"text","text":"Read only"}]}]}))
    modal = UI.display_modal(title: UI.plain("Notes"), &.rich_text({quote}))
    home = UI.home(&.rich_text({quote}))
    JSON.parse(modal.to_json)["blocks"][0].should eq wire
    JSON.parse(home.to_json)["blocks"][0].should eq wire
  end
end

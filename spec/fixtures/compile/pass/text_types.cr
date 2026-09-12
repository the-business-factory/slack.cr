require "../../../support/block_kit/ui_only"

plain = Slack::UI::Checked::CompositionObjects::PlainText.new("Approve", emoji: true)
markdown = Slack::UI::Checked::CompositionObjects::Mrkdwn.new("*Approved*", verbatim: true)
button = Slack::UI::Checked::BlockElements::Button.new(text: plain)
section = Slack::UI::Checked::Blocks::Section.new(text: markdown, accessory: button)

raise "wrong plain text type" unless JSON.parse(plain.to_json)["type"] == "plain_text"
raise "wrong markdown type" unless JSON.parse(section.to_json)["text"]["type"] == "mrkdwn"

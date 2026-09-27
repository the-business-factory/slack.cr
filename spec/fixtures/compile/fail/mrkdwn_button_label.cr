require "../../../support/block_kit/ui_only"

markdown = Slack::UI::Checked::CompositionObjects::Mrkdwn.new("*Approve*")
Slack::UI::Checked::BlockElements::Button.new(text: markdown)

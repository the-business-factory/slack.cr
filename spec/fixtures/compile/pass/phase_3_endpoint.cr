require "../../../../src/slack"

{Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Display")) { |builder| builder.divider },
 Slack::UI::Checked.form_modal(title: Slack::UI::Checked.plain("Form"), submit: Slack::UI::Checked.plain("Send")) { |builder| builder.divider }}.each do |view|
  request = Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic", trigger_id: "trigger", view: view)
  request.to_json
  request.result
  request.call
end

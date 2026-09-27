require "slack"

# No spec helper, dotenv, credentials, or feature configuration at startup.
Habitat.raise_if_missing_settings!
raise "Unexpected client ID" unless Slack.settings.client_id.nil?
raise "Unexpected client secret" unless Slack.settings.client_secret.nil?
raise "Unexpected signing secret" unless Slack.settings.signing_secret.nil?
raise "Unexpected login redirect" unless Slack::SignInWithSlack.settings.sign_in_redirect_url.nil?

message = Slack::UI::Checked.message(fallback_text: "No credentials required") do |builder|
  builder.section(Slack::UI::Checked.plain("Ready"))
end
raise "Incorrect message" unless JSON.parse(message.to_json)["blocks"][0]["text"]["text"] == "Ready"

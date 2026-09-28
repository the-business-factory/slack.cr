# Run with: crystal run examples/slash_command.cr
# Synthetic signed slash command; the response_url post is stubbed and does not contact Slack.
require "./support/slash_command_example"

OfflineSlashCommandExample.run

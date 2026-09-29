require "../../../../src/slack"

client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxb-synthetic"))
app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))
app.event(Slack::Events::AppMentoined) { |ctx| ctx.log.info { ctx.event.type } }

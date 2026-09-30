# A consumer program that reaches the library only through `require "slack"` on
# CRYSTAL_PATH: no spec helper, credentials, or global configuration. It is
# built, but not run, by spec/entrypoints_spec.cr.
require "slack"

message = Slack::UI.message(fallback_text: "No credentials required") do |builder|
  builder.section(Slack::UI.plain("Ready"))
end
message.to_json

# Test support loads only with `require "slack/testing"`.
{% if Slack.has_constant?("Testing") %}
  {% raise "require \"slack\" loaded Slack::Testing" %}
{% end %}

# An App with no listener in an HTTP::Server handler chain. Codegen failed for
# this program with "GEP into unsized type" on Crystal 1.21.1, so the check
# builds it with codegen.
class Health
  include HTTP::Handler

  def call(context : HTTP::Server::Context) : Nil
    context.response.print "ok"
  end
end

client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxb-synthetic"))
app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))
verifier = Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new("synthetic"))
server = HTTP::Server.new([Slack::App::HttpReceiver.new(app, verifier), Health.new])
server.bind_tcp("127.0.0.1", 0)
server.listen

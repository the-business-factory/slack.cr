require "http"
require "uri"
require "../../../src/slack/testing"

# Builds signed synthetic Slack requests with `Slack::Testing::SignedRequest`
# and runs them through receiver handlers.
module AppSupport
  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-app-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)
  PATH           = "/slack/events"

  def self.json(body : String, headers : HTTP::Headers = HTTP::Headers.new) : HTTP::Request
    signed(body, "application/json", headers)
  end

  def self.form(params : Hash(String, String)) : HTTP::Request
    signed(URI::Params.encode(params), "application/x-www-form-urlencoded")
  end

  def self.interaction(payload : String) : HTTP::Request
    form({"payload" => payload})
  end

  def self.signed(body : String, content_type : String, headers : HTTP::Headers = HTTP::Headers.new,
                  path : String = PATH) : HTTP::Request
    request = Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, path: path, content_type: content_type)
    headers.each { |name, values| request.headers[name] = values }
    request
  end

  record Reply, status : Int32, content_type : String?, body : String, headers : HTTP::Headers

  # Runs *request* through *handler* and returns the written response.
  def self.run(handler : HTTP::Handler, request : HTTP::Request) : Reply
    output = IO::Memory.new
    response = HTTP::Server::Response.new(output)
    context = HTTP::Server::Context.new(request, response)
    handler.call(context)
    response.close
    parsed = HTTP::Client::Response.from_io(output.rewind)
    Reply.new(parsed.status_code, parsed.headers["Content-Type"]?, parsed.body, parsed.headers)
  end
end

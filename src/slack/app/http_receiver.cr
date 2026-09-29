require "http"
require "log"
require "uri"

# An `HTTP::Handler` that serves Slack's Events API, interactivity, options,
# and slash command requests on one path.
#
# For each POST to *path*, the receiver reads the body once and verifies it,
# answers a `url_verification` challenge, decodes the payload by content type
# (JSON events, a form `payload` field for interactions, other forms as slash
# commands), and writes the `App#dispatch` outcome. Requests for other paths go
# to the next handler, so application routes are ordinary handlers:
#
# ```
# HTTP::Server.new([Slack::App::HttpReceiver.new(app, verifier), HealthHandler.new])
# ```
#
# Responses: 200 with an empty or JSON body; 400 for a payload that does not
# decode; 401 for a failed verification or authorization; 405 for another
# method; 415 for another content type; 500 when routing or a listener raises
# before acknowledging. Logs never contain bodies, headers, or tokens.
#
# The receiver decodes verified bodies with *decoder*. Give a decoder with an
# observer to capture the exact bytes of each payload; see `Slack::Decoder`.
class Slack::App::HttpReceiver
  include HTTP::Handler

  Log = ::Log.for("slack.app.receiver")

  private JSON_TYPE = "application/json"
  private FORM_TYPE = "application/x-www-form-urlencoded"

  def initialize(@app : App, @verifier : Slack::Webhooks::Verifier, @path : String = "/slack/events",
                 *, @decoder : Slack::Decoder = Slack::Decoder.default)
  end

  def call(context : HTTP::Server::Context) : Nil
    request = context.request
    return call_next(context) unless request.path == @path
    response = context.response
    return finish(response, :method_not_allowed) unless request.method == "POST"
    body = verify(request) || return finish(response, :unauthorized)
    case media_type(request)
    when JSON_TYPE then answer_events(response, request, body)
    when FORM_TYPE then answer_form(response, body)
    else                finish(response, :unsupported_media_type)
    end
  end

  private def verify(request : HTTP::Request) : String?
    @verifier.verify(request).body
  rescue error : Slack::Errors::SignatureMismatch | Slack::Errors::ReplayAttack
    Log.warn { "Rejected an unverified request: #{error.class}" }
    nil
  end

  private def answer_events(response : HTTP::Server::Response, request : HTTP::Request, body : String) : Nil
    case envelope = decode { @decoder.event(body) }
    when Nil                    then finish(response, :bad_request)
    when Slack::UrlVerification then write_json(response, envelope.response.to_json)
    when Slack::VerifiedEvent   then answer(response, @app.dispatch(envelope, Slack::Events::Delivery.from_headers(request.headers)))
    else
      # Other outer envelopes, such as `app_rate_limited`, carry no event to route.
      Log.warn { "Acknowledged an envelope without an event: #{envelope.class}" }
      finish(response, :ok)
    end
  end

  # Slack checks the certificate of a slash command URL with a form that holds `ssl_check`.
  private def answer_form(response : HTTP::Server::Response, body : String) : Nil
    params = URI::Params.parse(body)
    return finish(response, :ok) if params.has_key?("ssl_check")
    payload = if params.has_key?("payload")
                decode { @decoder.interaction(body) }
              else
                decode { @decoder.command(body) }
              end
    payload ? answer(response, @app.dispatch(payload)) : finish(response, :bad_request)
  end

  private def decode(&)
    yield
  rescue error : JSON::ParseException | JSON::SerializableError | Slack::Auth::RequestAuthorizationError
    Log.warn { "Rejected a payload that does not decode: #{error.class}" }
    nil
  end

  private def answer(response : HTTP::Server::Response, outcome : Outcome) : Nil
    case outcome.status
    in .acknowledged?
      if json = outcome.json
        write_json(response, json)
      else
        finish(response, :ok)
      end
    in .unauthorized? then finish(response, :unauthorized)
    in .failed?       then finish(response, :internal_server_error)
    end
  end

  private def media_type(request : HTTP::Request) : String?
    request.headers["Content-Type"]?.try(&.split(';', 2).first.strip.downcase)
  end

  private def write_json(response : HTTP::Server::Response, json : String) : Nil
    response.status = :ok
    response.content_type = JSON_TYPE
    response.print(json)
  end

  private def finish(response : HTTP::Server::Response, status : HTTP::Status) : Nil
    response.status = status
  end
end

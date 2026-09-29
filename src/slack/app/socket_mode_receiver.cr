require "log"

# Serves Slack's Events API, interactivity, options, and slash command
# payloads that arrive over Socket Mode, and sends each `App#dispatch` outcome
# as the envelope acknowledgment.
#
# ```
# app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))
# socket = Slack::SocketMode::Client.new(Slack::Auth::Secret.new(ENV["SLACK_APP_TOKEN"]))
# Slack::App::SocketModeReceiver.new(app, socket).run
# ```
#
# Slack authenticates the WebSocket with the app-level token, so the receiver
# does not verify signatures. The `SocketMode::Client` owns the connection:
# it opens, refreshes, and reconnects it, and it starts one fiber for each
# envelope. The receiver decodes the envelope in that fiber, calls
# `App#dispatch`, and acknowledges:
#
# - `events_api`, `interactive`, and `slash_commands` envelopes go to the
#   app. The acknowledgment carries the listener's `ack` body, for example a
#   `Commands::Response` or `Interactions::ModalErrors`, when the envelope
#   accepts a response payload. Otherwise the body is dropped with a warning.
# - An `events_api` envelope gives the listener an `Events::Delivery` from
#   `retry_attempt` and `retry_reason`.
# - Envelopes of an unknown type, and events without a routable event, get an
#   empty acknowledgment.
#
# An envelope stays unacknowledged, so Slack can deliver it again, when its
# payload does not decode, authorization fails, or routing or a listener
# raises before the acknowledgment. The HTTP receiver answers these cases with
# a 4xx or 5xx status. Logs never contain payloads or tokens.
#
# The receiver decodes payloads with *decoder*. Give a decoder with an
# observer to capture the exact bytes of each payload; see `Slack::Decoder`.
class Slack::App::SocketModeReceiver
  Log = ::Log.for("slack.app.socket_mode_receiver")

  def initialize(@app : App, @client : Slack::SocketMode::Client, *,
                 @decoder : Slack::Decoder = Slack::Decoder.default)
  end

  # Receives envelopes until `#close` or until Slack turns Socket Mode off for
  # the app (`link_disabled`). It returns after every running listener has
  # acknowledged or reached the acknowledgment deadline.
  def run : Nil
    @client.run { |envelope, acknowledger| receive(envelope, acknowledger) }
  end

  # Asks `#run` to stop. It does not wait for `#run` to return.
  def close : Nil
    @client.close
  end

  private def receive(envelope : Slack::SocketMode::Envelope, acknowledger : Slack::SocketMode::Acknowledger) : Nil
    case envelope.kind
    in .events_api?     then route(envelope, acknowledger) { @decoder.event(envelope.payload_json) }
    in .interactive?    then route(envelope, acknowledger) { @decoder.interaction(envelope.payload_json, :json) }
    in .slash_commands? then route(envelope, acknowledger) { @decoder.command(envelope.payload_json, :json) }
    in .unknown?
      Log.warn { "Acknowledged envelope #{envelope.envelope_id} of unknown type #{envelope.type.inspect}" }
      acknowledger.ack
    end
  end

  private def route(envelope : Slack::SocketMode::Envelope, acknowledger : Slack::SocketMode::Acknowledger, &) : Nil
    case payload = decode(envelope) { yield }
    when Nil
      # `decode` logged the failure.
    when Slack::VerifiedEvent
      acknowledge(envelope, acknowledger, @app.dispatch(payload, delivery(envelope)))
    when Slack::Command, Slack::Interaction
      acknowledge(envelope, acknowledger, @app.dispatch(payload))
    else
      # Other outer envelopes, such as `app_rate_limited`, carry no event to route.
      Log.warn { "Acknowledged envelope #{envelope.envelope_id} without an event: #{payload.class}" }
      acknowledger.ack
    end
  end

  private def decode(envelope : Slack::SocketMode::Envelope, &)
    yield
  rescue error : JSON::ParseException | JSON::SerializableError | Slack::Interactions::TypeMismatch | Slack::Auth::RequestAuthorizationError
    Log.warn { "Left envelope #{envelope.envelope_id} unacknowledged: the payload does not decode (#{error.class})" }
    nil
  end

  private def acknowledge(envelope : Slack::SocketMode::Envelope, acknowledger : Slack::SocketMode::Acknowledger,
                          outcome : Outcome) : Nil
    case outcome.status
    in .acknowledged?
      acknowledger.ack(accepted_body(envelope, outcome.body))
    in .unauthorized?, .failed?
      Log.warn { "Left envelope #{envelope.envelope_id} unacknowledged: #{outcome.status.to_s.downcase}" }
    end
  end

  private def accepted_body(envelope : Slack::SocketMode::Envelope, body : AckBody?) : AckBody?
    return body if body.nil? || envelope.accepts_response_payload?
    Log.warn { "Dropped the #{body.class} response of envelope #{envelope.envelope_id}: it accepts no response payload" }
    nil
  end

  # Slack SDKs send `retry_attempt` 0 and an empty `retry_reason` on a first
  # delivery. They read as nil, like the absent HTTP retry headers.
  private def delivery(envelope : Slack::SocketMode::Envelope) : Slack::Events::Delivery
    attempt = envelope.retry_attempt.try { |number| number if number > 0 }
    Slack::Events::Delivery.new(attempt, envelope.retry_reason.presence)
  end
end

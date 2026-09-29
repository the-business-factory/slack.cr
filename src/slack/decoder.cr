require "./commands/parse"
require "./events/parse"
require "./interactions/parse"

# Decodes Slack payloads into typed values. The decoder does not verify
# signatures: HTTP callers verify a request before they give its body to the
# decoder, and Slack authenticates a Socket Mode connection with the app-level
# token.
#
# `Slack::App::HttpReceiver`, `Slack::App::SocketModeReceiver`,
# `Slack::Auth::RequestAuthorizer`, and `Slack::Auth::CredentialLifecycle`
# take a decoder. The default is `Slack::Decoders::Fused`.
# `Slack::Decoders::Stdlib` decodes with the standard library `JSON` parser
# instead:
#
# ```
# Slack::App::HttpReceiver.new(app, verifier, decoder: Slack::Decoders::Stdlib.new)
# ```
#
# Give an observer to see each payload before the decoder decodes it, for
# example to keep a payload for a bug report or a test fixture:
#
# ```
# decoder = Slack::Decoders::Fused.new(->(kind : Slack::Decoder::Kind, body : String) {
#   File.write("captured-#{kind.to_s.downcase}.txt", body)
#   nil
# })
# Slack::App::HttpReceiver.new(app, verifier, decoder: decoder)
# ```
#
# The observer gets the exact bytes that the caller gives the decoder:
#
# - Over HTTP, the request body, after signature verification: JSON for an
#   event, and the form for an interaction or a slash command.
# - Over Socket Mode, `SocketMode::Envelope#payload_json`: the payload bytes
#   from the frame, with their whitespace and string escapes.
#
# The observer runs in the fiber that decodes the payload. If the observer
# raises, the decoder does not decode the payload and the exception goes to
# the caller.
#
# To make a decoder, inherit this class and implement the protected `decode_*`
# methods. Each one must raise `JSON::ParseException`, `JSON::SerializableError`,
# or `Slack::Auth::RequestAuthorizationError` for a payload that does not decode.
abstract class Slack::Decoder
  # The payload kind that the observer gets.
  enum Kind
    Event
    Interaction
    Command
  end

  # The encoding of an interaction or slash command payload.
  enum Format
    # An HTTP `application/x-www-form-urlencoded` body. An interaction is in its one `payload` field.
    Form
    # A JSON object, as in a Socket Mode envelope.
    JSON
  end

  alias Observer = Kind, String -> Nil

  # The decoder that receivers and authorizers use when you do not give one.
  class_getter default : Decoder { Decoders::Fused.new }

  def initialize(@observer : Observer? = nil)
  end

  # Decodes an Events API body.
  def event(body : String) : Slack::VerifiedEvent | Slack::UrlVerification | Slack::AppRateLimited
    observe(Kind::Event, body)
    decode_event(body)
  end

  # Decodes an interaction payload in *format*.
  def interaction(body : String, format : Format = Format::Form) : Slack::Interaction
    observe(Kind::Interaction, body)
    decode_interaction(body, format)
  end

  # Decodes a slash command payload in *format*.
  def command(body : String, format : Format = Format::Form) : Slack::Command
    observe(Kind::Command, body)
    decode_command(body, format)
  end

  protected abstract def decode_event(body : String) : Slack::VerifiedEvent | Slack::UrlVerification | Slack::AppRateLimited
  protected abstract def decode_interaction(body : String, format : Format) : Slack::Interaction
  protected abstract def decode_command(body : String, format : Format) : Slack::Command

  private def observe(kind : Kind, body : String) : Nil
    @observer.try &.call(kind, body)
  end
end

require "./decoders/stdlib"
require "./decoders/fused"

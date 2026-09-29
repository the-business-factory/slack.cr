require "../decoder"

# A `Slack::Decoder` that decodes with the standard library `JSON` parser
# through `Slack::Events.parse`, `Slack::Interactions.parse`, and
# `Slack::Commands.parse`. The default decoder is `Slack::Decoders::Fused`.
#
# ```
# Slack::App::SocketModeReceiver.new(app, socket, decoder: Slack::Decoders::Stdlib.new)
# ```
class Slack::Decoders::Stdlib < Slack::Decoder
  protected def decode_event(body : String) : Slack::VerifiedEvent | Slack::UrlVerification | Slack::AppRateLimited
    Slack::Events.parse(body)
  end

  protected def decode_interaction(body : String, format : Format) : Slack::Interaction
    case format
    in .form? then Slack::Interactions.parse(body)
    in .json? then Slack::Interaction.from_json(body)
    end
  end

  protected def decode_command(body : String, format : Format) : Slack::Command
    case format
    in .form? then Slack::Commands.parse(body)
    in .json? then Slack::Commands::Parser.from_json_object(body)
    end
  end
end

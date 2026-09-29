require "fused_json"
require "../decoder"

# The default `Slack::Decoder`. It decodes with the
# [FusedJSON](https://github.com/wyhaines/fused-json.cr) parser.
#
# For each payload, a scan reads only the discriminators: the `type` field,
# and for an Events API body the `type` and `subtype` of `event`. The scan
# selects the concrete type, and one typed parse decodes the payload into it.
# `Slack::Decoders::Stdlib` decodes the same payloads to the same values.
#
# FusedJSON is strict JSON: for example, it rejects a trailing comma. Error
# messages about malformed JSON can differ from the standard library ones.
class Slack::Decoders::Fused < Slack::Decoder
  protected def decode_event(body : String) : Slack::VerifiedEvent | Slack::UrlVerification | Slack::AppRateLimited
    discriminators = Discriminators.scan(body)
    case discriminators.type
    when "url_verification" then FusedJSON.from_json(body, Slack::UrlVerification)
    when "app_rate_limited" then FusedJSON.from_json(body, Slack::AppRateLimited)
    else                         event_callback(body, discriminators)
    end
  end

  protected def decode_interaction(body : String, format : Format) : Slack::Interaction
    case format
    in .form? then interaction_json(Slack::Interactions.form_payload(body))
    in .json? then interaction_json(body)
    end
  end

  protected def decode_command(body : String, format : Format) : Slack::Command
    case format
    in .form? then Slack::Commands.parse(body)
    in .json? then FusedJSON.from_json(body, CommandObject).command
    end
  end

  # Selects the event type from `Slack::Event::KNOWN_TYPES` and the message
  # subtype from `Slack::Events::MessageFactory::KNOWN_SUBTYPES`. A missing or
  # irregular discriminator goes through the `Slack::Event` selector, which
  # raises the same error classes as `Slack::Decoders::Stdlib`.
  private def event_callback(body : String, discriminators : Discriminators) : Slack::VerifiedEvent
    return FusedJSON.from_json(body, Slack::VerifiedEvent) unless discriminators.regular?

    {% begin %}
      case discriminators.event_type
      {% for type, event in Slack::Event::KNOWN_TYPES %}
        {% if type == "message" %}
          when "message" then message_callback(body, discriminators.subtype)
        {% else %}
          when {{ type }} then envelope(body, {{ event }})
        {% end %}
      {% end %}
      when Nil then FusedJSON.from_json(body, Slack::VerifiedEvent)
      else          envelope(body, Slack::Events::Unknown)
      end
    {% end %}
  end

  private def message_callback(body : String, subtype : String?) : Slack::VerifiedEvent
    {% begin %}
      case subtype
      {% for name, event in Slack::Events::MessageFactory::KNOWN_SUBTYPES %}
        when {{ name }} then envelope(body, {{ event }})
      {% end %}
      when Nil then envelope(body, Slack::Events::Message)
      else          envelope(body, Slack::Events::Message::Unmapped)
      end
    {% end %}
  end

  private def envelope(body : String, event_type : E.class) : Slack::VerifiedEvent forall E
    FusedJSON.from_json(body, Envelope(E)).to_verified_event
  end

  # Selects the interaction type from `Slack::Interaction::KNOWN_TYPES`.
  private def interaction_json(json : String) : Slack::Interaction
    discriminators = Discriminators.scan(json)
    return FusedJSON.from_json(json, Slack::Interaction) unless discriminators.regular?

    {% begin %}
      case discriminators.type
      {% for type, interaction in Slack::Interaction::KNOWN_TYPES %}
        when {{ type }} then FusedJSON.from_json(json, {{ interaction }})
      {% end %}
      when Nil then FusedJSON.from_json(json, Slack::Interaction)
      else          FusedJSON.from_json(json, Slack::Interactions::Unknown)
      end
    {% end %}
  end
end

require "./fused/*"

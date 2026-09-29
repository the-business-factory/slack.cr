# :nodoc:
# An Events API `event_callback` envelope whose `event` has the concrete
# type *E*. `Slack::Decoders::Fused` decodes into it after a scan selects *E*,
# so the event decodes in the same pass as the envelope.
#
# The fields come from `Slack::Events::EnvelopeFields.declare`, as in
# `Slack::VerifiedEvent`, so the two field lists stay the same.
struct Slack::Decoders::Fused::Envelope(E)
  include JSON::Serializable
  include Slack::InitializerMacros

  Slack::Events::EnvelopeFields.declare(E)

  # Returns a `Slack::VerifiedEvent` with the same field values.
  def to_verified_event : Slack::VerifiedEvent
    {% begin %}
      Slack::VerifiedEvent.new(
        {% for ivar in @type.instance_vars %}
          {{ ivar.name }}: @{{ ivar.name }},
        {% end %}
      )
    {% end %}
  end
end

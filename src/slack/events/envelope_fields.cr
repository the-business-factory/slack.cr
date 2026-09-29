# :nodoc:
# Holds the one list of Events API envelope fields.
#
# `Slack::VerifiedEvent` declares its fields with `declare`. A type that
# decodes the same envelope, for example a generic `Envelope(E)`, must also
# use `declare`, so that the two field lists cannot drift apart.
module Slack::Events::EnvelopeFields
  # Declares the envelope fields in the calling type, with `event` typed as
  # *event_type*.
  #
  # The calling type must include `JSON::Serializable` and
  # `Slack::InitializerMacros`. The declaration order sets the key order of
  # `to_json`; do not change it.
  macro declare(event_type)
    properties_with_initializer \
      api_app_id : String,
      authorizations : Array(Slack::Events::Authorization) = [] of Slack::Events::Authorization,
      event : {{ event_type }},
      event_context : String? = nil,
      event_id : String,
      team_id : String? = nil,
      token : String,
      type : String

    @[JSON::Field(emit_null: false)]
    properties_with_initializer context_enterprise_id : String? = nil

    @[JSON::Field(emit_null: false)]
    properties_with_initializer context_team_id : String? = nil

    @[JSON::Field(emit_null: false)]
    properties_with_initializer is_ext_shared_channel : Bool? = nil

    @[JSON::Field(converter: Slack::EpochConverter)]
    properties_with_initializer event_time : Time
  end
end

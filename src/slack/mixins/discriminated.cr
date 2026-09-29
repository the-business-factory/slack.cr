# :nodoc:
# Decodes a JSON object as one of several types, selected by a string field.
#
# Include this module and call `discriminated_by` in the type body.
module Slack::Discriminated
  # Generates `self.new(pull)`, which selects a type by the string *field*.
  #
  # *mapping* pairs discriminator values with types. A value that is not in
  # *mapping* builds *fallback* with `new(value, raw)`. When *default* is
  # given, a missing or null field decodes as *default*; otherwise it raises
  # `JSON::SerializableError`.
  #
  # Also defines `KNOWN_<FIELD>S`, the mapping as a Hash constant. When a
  # mapped type is itself discriminated with a *default*, the constant gives
  # that default type (its `Default` alias), so each value is a decoded type.
  # The mapped type must be defined before this macro expands.
  #
  # With *default*, also defines the alias `Default`. A concrete (not
  # abstract) type that only selects other types gets no return type
  # restriction, because it does not return itself.
  macro discriminated_by(field, mapping, *, fallback, default = nil)
    {% unless mapping.is_a?(NamedTupleLiteral) %}
      {% mapping.raise "mapping must be a NamedTupleLiteral, not #{mapping.class_name.id}" %}
    {% end %}

    {% if default %}
      # The type that an object without a `{{ field.id }}` decodes as.
      alias Default = {{ default }}
    {% end %}

    # The `{{ field.id }}` values that decode as a mapped type.
    KNOWN_{{ field.id.upcase }}S = {
      {% for key, value in mapping %}
        {% resolved = value.resolve? %}
        {% if resolved && resolved.ancestors.includes?(::Slack::Discriminated.resolve) && resolved.has_constant?("Default") %}
          {{ key.id.stringify }} => {{ value }}::Default,
        {% else %}
          {{ key.id.stringify }} => {{ value }},
        {% end %}
      {% end %}
    }

    # Decodes a JSON object as the type that its `{{ field.id }}` field selects.
    # See `KNOWN_{{ field.id.upcase }}S`.
    def self.new(pull : ::JSON::PullParser){% if @type.abstract? %} : self{% end %}
      location = pull.location
      raw = ::JSON::Any.new(pull)
      discriminator = ::Slack::Discriminated.value(raw, {{ field.id.stringify }}, {{ @type.stringify }}, location)
      json = raw.to_json

      case discriminator
      {% for key, value in mapping %}
      when {{ key.id.stringify }} then {{ value }}.from_json(json)
      {% end %}
      when Nil
        {% if default %}
          {{ default }}.from_json(json)
        {% else %}
          raise ::JSON::SerializableError.new("Missing string JSON discriminator field '{{ field.id }}'", {{ @type.stringify }}, nil, *location, nil)
        {% end %}
      else
        {{ fallback }}.new(discriminator, raw)
      end
    end
  end

  # Returns the string *field* of the JSON object *raw*, or nil when the field
  # is missing or null. Raises `JSON::SerializableError` with *owner* when
  # *raw* is not an object or the field has another JSON type.
  def self.value(raw : JSON::Any, field : String, owner : String, location : Tuple(Int32, Int32)) : String?
    object = raw.as_h? || raise JSON::SerializableError.new("Expected a JSON object", owner, nil, *location, nil)
    value = object[field]?
    return if value.nil? || value.raw.nil?
    value.as_s? || raise JSON::SerializableError.new("JSON discriminator field '#{field}' must be a string", owner, nil, *location, nil)
  end
end

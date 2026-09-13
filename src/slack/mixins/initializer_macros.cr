# Heavy inspiration lifted from Lucky's ```needs``` implementation:
# https://github.com/luckyframework/lucky/blob/main/src/lucky/assignable.cr#L24
module Slack::InitializerMacros
  macro properties_with_initializer(*type_declarations)
    {% unless type_declarations.all?(&.is_a?(TypeDeclaration)) %}
      {% raise "'properties_with_initializer' expects an array of type declarations" %}
    {% end %}

    property {{ type_declarations.splat }}

    {% for declaration in type_declarations.sort_by(&.var.id) %}
      {% ASSIGNED_TYPES << declaration %}
    {% end %}
  end

  # Adds a nilable property that remains a required initializer argument.
  # Use this only when nil has meaning distinct from an omitted argument.
  macro required_properties_with_initializer(*type_declarations)
    {% unless type_declarations.all?(&.is_a?(TypeDeclaration)) %}
      {% raise "'required_properties_with_initializer' expects an array of type declarations" %}
    {% end %}

    property {{ type_declarations.splat }}

    {% for declaration in type_declarations.sort_by(&.var.id) %}
      {% ASSIGNED_TYPES << declaration %}
      {% REQUIRED_ASSIGNED_NAMES << declaration.var.id %}
    {% end %}
  end

  # Adds properties that can be passed only by name to generated initializers.
  macro named_properties_with_initializer(*type_declarations)
    {% unless type_declarations.all?(&.is_a?(TypeDeclaration)) %}
      {% raise "'named_properties_with_initializer' expects an array of type declarations" %}
    {% end %}

    property {{ type_declarations.splat }}

    {% for declaration in type_declarations.sort_by(&.var.id) %}
      {% NAMED_ASSIGNED_TYPES << declaration %}
    {% end %}
  end

  macro setup_initializer_hook
    macro finished
      generate_initializer
    end

    macro included
      setup_initializer_hook
    end

    macro inherited
      setup_initializer_hook
    end
  end

  macro inherit_assigns
    macro included
      inherit_assigns
    end

    macro inherited
      inherit_assigns
    end

    {% if !@type.has_constant?(:ASSIGNED_TYPES) %}
      ASSIGNED_TYPES = [] of TypeDeclaration
      NAMED_ASSIGNED_TYPES = [] of TypeDeclaration
      REQUIRED_ASSIGNED_NAMES = [] of MacroId
      {% verbatim do %}
        {% if @type.ancestors.first %}
          {% for declaration in @type.ancestors.first.constant(:ASSIGNED_TYPES) %}
            {% ASSIGNED_TYPES << declaration %}
          {% end %}
          {% for declaration in @type.ancestors.first.constant(:NAMED_ASSIGNED_TYPES) %}
            {% NAMED_ASSIGNED_TYPES << declaration %}
          {% end %}
          {% for name in @type.ancestors.first.constant(:REQUIRED_ASSIGNED_NAMES) %}
            {% REQUIRED_ASSIGNED_NAMES << name %}
          {% end %}
        {% end %}
      {% end %}
    {% end %}
  end

  macro generate_initializer
    {% if !@type.abstract? && ASSIGNED_TYPES.first %}
      {% sorted_assigns = ASSIGNED_TYPES.sort_by do |dec|
           required = REQUIRED_ASSIGNED_NAMES.includes?(dec.var.id)
           has_explicit_value = !required &&
                                (dec.type.is_a?(Metaclass) ||
                                 dec.type.types.map(&.id).includes?(Nil.id) ||
                                 !dec.value.is_a?(Nop))
           has_explicit_value ? 1 : 0
         end %}
      def initialize(
        {% for declaration in sorted_assigns %}
          {% var = declaration.var %}
          {% type = declaration.type %}
          {% value = declaration.value %}
          {% required = REQUIRED_ASSIGNED_NAMES.includes?(var.id) %}
          {% value = nil if !required && type.stringify.ends_with?("Nil") && !value %}
          @{{ var.id }} : {{ type }}{% if !value.is_a?(Nop) %} = {{ value }}{% end %},
        {% end %}
        {% if NAMED_ASSIGNED_TYPES.first %}
          *,
          {% for declaration in NAMED_ASSIGNED_TYPES %}
            {% var = declaration.var %}
            {% type = declaration.type %}
            {% value = declaration.value %}
            {% value = nil if type.stringify.ends_with?("Nil") && !value %}
            @{{ var.id }} : {{ type }}{% if !value.is_a?(Nop) %} = {{ value }}{% end %},
          {% end %}
        {% end %}
        )

        {% if @type.has_method? "after_initialize" %}
          after_initialize
        {% end %}
      end
    {% end %}
  end

  inherit_assigns
  setup_initializer_hook
end

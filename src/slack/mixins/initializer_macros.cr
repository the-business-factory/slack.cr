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
      {% verbatim do %}
        {% if @type.ancestors.first %}
          {% for declaration in @type.ancestors.first.constant(:ASSIGNED_TYPES) %}
            {% ASSIGNED_TYPES << declaration %}
          {% end %}
        {% end %}
      {% end %}
    {% end %}
  end

  macro generate_initializer
    {% if !@type.abstract? && ASSIGNED_TYPES.first %}
      {% sorted_assigns = ASSIGNED_TYPES.sort_by { |dec|
           has_explicit_value =
             dec.type.is_a?(Metaclass) ||
               dec.type.types.map(&.id).includes?(Nil.id) ||
               !dec.value.is_a?(Nop)
           has_explicit_value ? 1 : 0
         } %}
      def initialize(
        {% for declaration in sorted_assigns %}
          {% var = declaration.var %}
          {% type = declaration.type %}
          {% value = declaration.value %}
          {% value = nil if type.stringify.ends_with?("Nil") && !value %}
          @{{ var.id }} : {{ type }}{% if !value.is_a?(Nop) %} = {{ value }}{% end %},
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

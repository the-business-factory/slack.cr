module Slack::UI::DynamicTextComposition
  macro included
    include JSON::Serializable
    include Slack::InitializerMacros
  end

  macro text_object(klass, **options)
    struct {{ klass.id }}
      property text : String,
        type : String,
        emoji : Bool = false,
        verbatim : Bool = false

      def initialize(@text,
                     @type = {{ options[:type] }} || "plain_text",
                     @emoji = {{ options[:emoji] }} || false,
                     @verbatim = false)
        after_initialize
      end

      def after_initialize
        max = {{ options[:max_length] }}
        return unless max

        if @text.size > max
          raise Errors::InvalidUIBlock.new(
            "Text cannot be longer than #{max} characters."
          )
        end
      end

      def to_json(json : JSON::Builder)
        case type
        when "plain_text"
          json.object do
            json.field "type", type
            json.field "text", text
            json.field "emoji", emoji
          end
        else
          json.object do
            json.field "type", type
            json.field "text", text
            json.field "verbatim", verbatim
          end
        end
      end

      def empty?
        text.empty?
      end
    end
  end
end

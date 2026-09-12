module Slack::UI::Checked::CompositionObjects
  struct PlainText
    getter text : String
    getter? emoji : Bool

    def initialize(@text : String, @emoji : Bool = false)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "type", "plain_text"
        json.field "text", @text
        json.field "emoji", @emoji
      end
    end
  end

  struct Mrkdwn
    getter text : String
    getter? verbatim : Bool

    def initialize(@text : String, @verbatim : Bool = false)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "type", "mrkdwn"
        json.field "text", @text
        json.field "verbatim", @verbatim
      end
    end
  end

  alias Text = PlainText | Mrkdwn
end

module Slack::UI::Checked::Blocks
  struct Section
    alias Text = Slack::UI::Checked::CompositionObjects::Text
    alias Accessory = Slack::UI::Checked::BlockElements::Button

    @text : Text?
    @fields : Array(Text)?

    getter text : Text?
    getter accessory : Accessory?
    getter block_id : String?

    def initialize(
      @text : Text,
      @accessory : Accessory? = nil,
      @block_id : String? = nil,
    )
      @fields = nil
    end

    def initialize(
      fields : Enumerable(T),
      @accessory : Accessory? = nil,
      @block_id : String? = nil,
    ) forall T
      DeclaredTypes.text(T)
      @text = nil
      @fields = copy_fields(fields)
    end

    def initialize(
      @text : Text,
      fields : Enumerable(T),
      @accessory : Accessory? = nil,
      @block_id : String? = nil,
    ) forall T
      DeclaredTypes.text(T)
      @fields = copy_fields(fields)
    end

    def fields : Array(Text)?
      @fields.try(&.dup)
    end

    def validate : Array(Slack::UI::Checked::ValidationIssue)
      [] of Slack::UI::Checked::ValidationIssue
    end

    def validate! : Nil
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "type", "section"
        json.field "text", @text if @text
        json.field "fields", @fields if @fields
        json.field "accessory", @accessory if @accessory
        json.field "block_id", @block_id if @block_id
      end
    end

    private def copy_fields(fields : Enumerable(T)) : Array(Text) forall T
      copied = [] of Text
      fields.each { |field| append_field(copied, field) }
      copied
    end

    private def append_field(fields : Array(Text), field : CompositionObjects::PlainText) : Nil
      fields << field
    end

    private def append_field(fields : Array(Text), field : CompositionObjects::Mrkdwn) : Nil
      fields << field
    end
  end
end

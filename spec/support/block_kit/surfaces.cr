module Slack::UI::Checked::Proof
  # These controls prove nested generic restrictions only. They do not claim
  # that Slack supports the represented Home or modal placements.
  struct SyntheticCommonInput
    getter value : String

    def initialize(@value : String)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "type", "synthetic_common_input"
        json.field "value", @value
      end
    end
  end

  struct SyntheticModalInput
    getter value : String

    def initialize(@value : String)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "type", "synthetic_modal_input"
        json.field "value", @value
      end
    end
  end

  struct SyntheticHomeInput
    getter value : String

    def initialize(@value : String)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "type", "synthetic_home_input"
        json.field "value", @value
      end
    end
  end

  struct SyntheticForbiddenInput
    getter value : String

    def initialize(@value : String)
    end
  end

  struct Input(T)
    getter element : T

    def initialize(@element : T)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "type", "input"
        json.field "element", @element
      end
    end
  end

  alias FormInputElement = SyntheticCommonInput | SyntheticModalInput
  alias HomeInputElement = SyntheticCommonInput | SyntheticHomeInput
  alias FormInput = Input(FormInputElement)
  alias HomeInput = Input(HomeInputElement)
  alias Section = Slack::UI::Checked::Blocks::Section
  alias DisplayModalSourceBlock = Section
  alias DisplayModalBlock = Section
  alias FormModalSourceBlock = Section |
                               Input(SyntheticCommonInput) |
                               Input(SyntheticModalInput) |
                               Input(FormInputElement)
  alias FormModalBlock = FormModalSourceBlock
  alias HomeSourceBlock = Section |
                          Input(SyntheticCommonInput) |
                          Input(SyntheticHomeInput) |
                          Input(HomeInputElement)
  alias HomeBlock = HomeSourceBlock
  alias MessageSourceBlock = Section
  alias MessageBlock = Section

  struct DisplayModal
    @blocks : Array(DisplayModalBlock)

    getter title : Slack::UI::Checked::CompositionObjects::PlainText

    def initialize(
      @title : Slack::UI::Checked::CompositionObjects::PlainText,
      blocks : Enumerable(T),
    ) forall T
      Slack::UI::Checked::Proof::DeclaredTypes.display_modal_block(T)
      @blocks = copy_blocks(blocks)
    end

    def blocks : Array(DisplayModalBlock)
      @blocks.dup
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "type", "modal"
        json.field "title", @title
        json.field "blocks", @blocks
      end
    end

    private def copy_blocks(blocks : Enumerable(T)) : Array(DisplayModalBlock) forall T
      copied = [] of DisplayModalBlock
      blocks.each { |block| append_block(copied, block) }
      copied
    end

    private def append_block(blocks : Array(DisplayModalBlock), block : Section) : Nil
      blocks << block
    end
  end

  struct FormModal
    @blocks : Array(FormModalBlock)

    getter title : Slack::UI::Checked::CompositionObjects::PlainText
    getter submit : Slack::UI::Checked::CompositionObjects::PlainText

    def initialize(
      @title : Slack::UI::Checked::CompositionObjects::PlainText,
      @submit : Slack::UI::Checked::CompositionObjects::PlainText,
      blocks : Enumerable(T),
    ) forall T
      Slack::UI::Checked::Proof::DeclaredTypes.form_modal_block(T)
      @blocks = copy_blocks(blocks)
    end

    def blocks : Array(FormModalBlock)
      @blocks.dup
    end

    def validate : Array(Slack::UI::Checked::ValidationIssue)
      [] of Slack::UI::Checked::ValidationIssue
    end

    def validate! : Nil
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "type", "modal"
        json.field "title", @title
        json.field "submit", @submit
        json.field "blocks", @blocks
      end
    end

    private def copy_blocks(blocks : Enumerable(T)) : Array(FormModalBlock) forall T
      copied = [] of FormModalBlock
      blocks.each { |block| append_block(copied, block) }
      copied
    end

    private def append_block(blocks : Array(FormModalBlock), block : Section) : Nil
      blocks << block
    end

    private def append_block(
      blocks : Array(FormModalBlock),
      block : Input(SyntheticCommonInput),
    ) : Nil
      blocks << block
    end

    private def append_block(
      blocks : Array(FormModalBlock),
      block : Input(SyntheticModalInput),
    ) : Nil
      blocks << block
    end

    private def append_block(blocks : Array(FormModalBlock), block : FormInput) : Nil
      blocks << block
    end
  end

  class FormModalBuilder
    @blocks = [] of FormModalBlock

    def initialize(
      @title : Slack::UI::Checked::CompositionObjects::PlainText,
      @submit : Slack::UI::Checked::CompositionObjects::PlainText,
    )
    end

    def add(block : Section) : Nil
      @blocks << block
    end

    def add(block : Input(SyntheticCommonInput)) : Nil
      @blocks << block
    end

    def add(block : Input(SyntheticModalInput)) : Nil
      @blocks << block
    end

    def add(block : FormInput) : Nil
      @blocks << block
    end

    def add_all(blocks : Enumerable(T)) : Nil forall T
      Slack::UI::Checked::Proof::DeclaredTypes.form_modal_block(T)
      blocks.each { |block| add(block) }
    end

    def build : FormModal
      FormModal.new(title: @title, submit: @submit, blocks: @blocks)
    end
  end

  struct Home
    @blocks : Array(HomeBlock)

    def initialize(blocks : Enumerable(T)) forall T
      Slack::UI::Checked::Proof::DeclaredTypes.home_block(T)
      @blocks = copy_blocks(blocks)
    end

    def blocks : Array(HomeBlock)
      @blocks.dup
    end

    private def copy_blocks(blocks : Enumerable(T)) : Array(HomeBlock) forall T
      copied = [] of HomeBlock
      blocks.each { |block| append_block(copied, block) }
      copied
    end

    private def append_block(blocks : Array(HomeBlock), block : Section) : Nil
      blocks << block
    end

    private def append_block(blocks : Array(HomeBlock), block : Input(SyntheticCommonInput)) : Nil
      blocks << block
    end

    private def append_block(blocks : Array(HomeBlock), block : Input(SyntheticHomeInput)) : Nil
      blocks << block
    end

    private def append_block(blocks : Array(HomeBlock), block : HomeInput) : Nil
      blocks << block
    end
  end

  struct Message
    @blocks : Array(MessageBlock)

    getter fallback_text : String

    def initialize(@fallback_text : String, blocks : Enumerable(T)) forall T
      Slack::UI::Checked::DeclaredTypes.message_block(T)
      @blocks = copy_blocks(blocks)
      validate!
    end

    def blocks : Array(MessageBlock)
      @blocks.dup
    end

    def snapshot : Message
      Message.new(fallback_text: @fallback_text, blocks: @blocks)
    end

    def validate : Array(Slack::UI::Checked::ValidationIssue)
      issues = [] of Slack::UI::Checked::ValidationIssue
      if @fallback_text.empty?
        issues << Slack::UI::Checked::ValidationIssue.new(
          code: "message.fallback_text.empty",
          path: "text",
          message: "Fallback text must not be empty."
        )
      end
      issues
    end

    def validate! : Nil
      issues = validate
      raise Slack::UI::Checked::ValidationError.new(issues) unless issues.empty?
    end

    def blocks_to_json(json : JSON::Builder) : Nil
      json.array do
        @blocks.each(&.to_json(json))
      end
    end

    private def copy_blocks(blocks : Enumerable(T)) : Array(MessageBlock) forall T
      copied = [] of MessageBlock
      blocks.each { |block| append_block(copied, block) }
      copied
    end

    private def append_block(blocks : Array(MessageBlock), block : Section) : Nil
      blocks << block
    end
  end

  struct ReusableSummary
    def initialize(@text : String)
    end

    def render : Section
      Section.new(text: Slack::UI::Checked::CompositionObjects::Mrkdwn.new(@text))
    end

    def render_into(builder : FormModalBuilder) : Nil
      builder.add(render)
    end
  end
end

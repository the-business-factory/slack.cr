struct Slack::UI::Modal < Slack::UI::Surface
  getter type : String = "modal"

  text_object Title, type: "plain_text", emoji: true, max_length: 24
  text_object Submit, type: "plain_text", emoji: true, max_length: 24
  text_object Close, type: "plain_text", emoji: true, max_length: 24

  properties_with_initializer \
    title : Title,
    submit : Submit? = nil,
    close : Close? = nil,
    blocks : Array(Slack::TypeAliases::ModalBlock)

  # Retains the positional order and external labels generated when all four
  # fields were required.
  def initialize(
    blocks legacy_blocks : Array(Slack::TypeAliases::ModalBlock),
    close legacy_close : Close,
    submit legacy_submit : Submit,
    title legacy_title : Title,
  )
    @blocks = legacy_blocks
    @close = legacy_close
    @submit = legacy_submit
    @title = legacy_title
    after_initialize
  end

  def after_initialize : Nil
    validate_submit!
  end

  def to_json(json : JSON::Builder) : Nil
    # Legacy arrays and setters remain mutable, so enforce the relationship
    # again immediately before a ViewsOpen request serializes this value.
    validate_submit!

    json.object do
      json.field "type", type
      json.field "title", title
      json.field "submit", submit unless submit.nil?
      json.field "close", close unless close.nil?
      json.field "blocks", blocks
    end
  end

  private def validate_submit! : Nil
    if @submit.nil? && @blocks.any?(Slack::UI::Blocks::Input)
      raise Errors::InvalidUIBlock.new(
        "Modal submit is required when blocks include an input"
      )
    end
  end
end

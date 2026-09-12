struct Slack::UI::Blocks::Actions < Slack::UI::Block
  alias Button = Slack::UI::BlockElements::Button

  getter type : String = "actions"

  property elements : Array(Button)
  property block_id : String?

  def initialize(elements : Array(Button)?, @block_id : String? = nil)
    @elements = required_elements(elements)
    after_initialize
  end

  # Retains the positional order and external labels generated before elements
  # became required.
  def initialize(
    block_id legacy_block_id : String?,
    elements legacy_elements : Array(Button)?,
  )
    @block_id = legacy_block_id
    @elements = required_elements(legacy_elements)
    after_initialize
  end

  def after_initialize : Nil
    if @elements.empty?
      raise Errors::InvalidUIBlock.new(
        "Actions block must have at least one element"
      )
    end

    if @elements.size > 25
      raise Errors::InvalidUIBlock.new(
        "Actions block can only have up to 25 elements"
      )
    end
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "block_id", block_id if block_id
      json.field "elements", elements
      json.field "type", type
    end
  end

  private def required_elements(elements : Array(Button)?) : Array(Button)
    elements || raise Errors::InvalidUIBlock.new(
      "Actions block elements are required"
    )
  end
end

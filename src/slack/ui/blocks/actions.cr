struct Slack::UI::Blocks::Actions < Slack::UI::Block
  getter type : String = "actions"

  properties_with_initializer \
    elements : Array(Slack::UI::BlockElements::Button)? = nil,
    block_id : String? = nil

  def after_initialize
    if @elements.try &.empty?
      raise Errors::InvalidUIBlock.new(
        "Actions block must have at least one element"
      )
    end

    if @elements.try &.size.>(5)
      raise Errors::InvalidUIBlock.new(
        "Actions block can only have up to 5 elements"
      )
    end
  end

  def to_json(json : JSON::Builder)
    json.object do
      json.field "block_id", block_id if block_id
      json.field "elements", elements
      json.field "type", type
    end
  end
end

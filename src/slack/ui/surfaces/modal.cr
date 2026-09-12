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

  def after_initialize : Nil
    if @submit.nil? && @blocks.any?(Slack::UI::Blocks::Input)
      raise Errors::InvalidUIBlock.new(
        "Modal submit is required when blocks include an input"
      )
    end
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "type", type
      json.field "title", title
      json.field "submit", submit unless submit.nil?
      json.field "close", close unless close.nil?
      json.field "blocks", blocks
    end
  end
end

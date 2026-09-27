# :nodoc:
# Builds display blocks through the concrete surface builder's typed add method.
module Slack::UI::Checked::DisplayBlockHelpers
  def section(
    text : Slack::UI::Checked::CompositionObjects::Text,
    accessory : Slack::UI::Checked::Blocks::Section::Accessory? = nil,
    block_id : String? = nil,
    expand : Bool? = nil,
  ) : Nil
    add(Slack::UI::Checked::Blocks::Section.new(
      text: text,
      accessory: accessory,
      block_id: block_id,
      expand: expand
    ))
  end

  def actions(elements : Enumerable(T), block_id : String? = nil) : Nil forall T
    add(Slack::UI::Checked::Blocks::Actions.new(elements: elements, block_id: block_id))
  end

  def divider(block_id : String? = nil) : Nil
    add(Slack::UI::Checked::Blocks::Divider.new(block_id: block_id))
  end

  def header(text : CompositionObjects::PlainText, block_id : String? = nil, level : Int32? = nil) : Nil
    add(Blocks::Header.new(text: text, block_id: block_id, level: level))
  end

  def context(elements : Enumerable(T), block_id : String? = nil) : Nil forall T
    add(Blocks::Context.new(elements: elements, block_id: block_id))
  end

  def image(*, alt_text : String, image_url : String, title : CompositionObjects::PlainText? = nil, block_id : String? = nil) : Nil
    add(Blocks::Image.new(alt_text: alt_text, image_url: image_url, title: title, block_id: block_id))
  end

  def image(*, alt_text : String, slack_file : CompositionObjects::SlackFile, title : CompositionObjects::PlainText? = nil, block_id : String? = nil) : Nil
    add(Blocks::Image.new(alt_text: alt_text, slack_file: slack_file, title: title, block_id: block_id))
  end
end

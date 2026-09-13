module Slack::UI::Checked::DisplayBlockHelpers
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
